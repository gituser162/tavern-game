extends Control
## The attic as a big puzzle grid (shown in the attic window, the attic has no shelves in the background).
## Every piece lies in its cells with its icon. Drag a piece with the mouse to another free spot, or onto the
## sale tray on the counter to offer it to the visitor (main.gd gives `tray_state` / `tray_drop`).

signal hovered(item_id: String, source: Control, uid: int)
signal drag_started
signal drag_finished

const GameData := preload("res://scripts/game_data.gd")
const Storage := preload("res://scripts/storage.gd")

const PLANK := Color("3a281a")
const PLANK_LIGHT := Color("4c3524")
const PLANK_DARK := Color("21160e")
const BACK := Color("150e09")

var place_id := "attic"
## Screen px per cell.
var cell := 40.0
## (item_id, mouse position) -> int: 0 = the mouse is not over the tray, 1 = the piece can go there, -1 = it cannot.
var tray_state: Callable
## (uid) -> bool: put the piece on the tray; true if it went there.
var tray_drop: Callable

var _nodes: Dictionary = {}
var _drag: Dictionary = {}
var _target := Rect2()
var _target_ok := false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS
	set_process_input(false)
	refresh()


func _grid() -> Dictionary:
	return Storage.grid_of(place_id)


func refresh() -> void:
	var g := _grid()
	custom_minimum_size = Vector2(g["cols"], g["rows"]) * cell
	if not _drag.is_empty():
		_cancel_drag()
	var alive := {}
	for p in GameState.storage.pieces(place_id):
		var uid: int = p["uid"]
		alive[uid] = true
		var t: TextureRect = _nodes.get(uid)
		if t == null or not is_instance_valid(t):
			t = _make_piece(p)
			_nodes[uid] = t
		var sz := Storage.piece_size(p)
		t.position = Vector2(p["x"], p["y"]) * cell
		t.size = Vector2(sz) * cell
		t.visible = not GameState.deal_has(uid)
	for uid in _nodes.keys():
		if not alive.has(uid):
			var t: TextureRect = _nodes[uid]
			_nodes.erase(uid)
			if is_instance_valid(t):
				t.queue_free()
	queue_redraw()


func _make_piece(p: Dictionary) -> TextureRect:
	var t := TextureRect.new()
	var id: String = p["id"]
	var uid: int = p["uid"]
	t.texture = GameData.icon_texture(id)
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	t.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	t.mouse_filter = Control.MOUSE_FILTER_STOP
	t.mouse_default_cursor_shape = Control.CURSOR_DRAG
	t.gui_input.connect(_on_piece_input.bind(uid, id, t))
	t.mouse_entered.connect(func() -> void:
		if _drag.is_empty():
			hovered.emit(id, t, uid))
	add_child(t)
	return t


func _draw() -> void:
	var g := _grid()
	var cols: int = g["cols"]
	var rows: int = g["rows"]
	draw_rect(Rect2(Vector2.ZERO, Vector2(cols, rows) * cell), BACK)
	# Every cell is a little wooden board: lit top edge, dark bottom edge (flat, pixel style).
	var px := maxf(2.0, roundf(cell / 16.0))
	for y in rows:
		for x in cols:
			var r := Rect2(Vector2(x, y) * cell + Vector2(px, px) * 0.5, Vector2(cell, cell) - Vector2(px, px))
			draw_rect(r, PLANK)
			draw_rect(Rect2(r.position, Vector2(r.size.x, px)), PLANK_LIGHT)
			draw_rect(Rect2(r.position + Vector2(0, r.size.y - px), Vector2(r.size.x, px)), PLANK_DARK)
	if _target.size.x > 0:
		var col := Color(0.45, 0.9, 0.4) if _target_ok else Color(0.95, 0.35, 0.3)
		draw_rect(_target, Color(col, 0.25))
		draw_rect(_target, col, false, 2.0)


# --- dragging ---

func _on_piece_input(event: InputEvent, uid: int, id: String, t: TextureRect) -> void:
	if not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT) or not _drag.is_empty():
		return
	_drag = {"uid": uid, "id": id, "node": t, "grab": event.global_position - t.global_position,
		"from": event.global_position, "start": t.position, "moved": false, "target": {}}
	t.accept_event()
	set_process_input(true)


func _input(event: InputEvent) -> void:
	if _drag.is_empty():
		set_process_input(false)
		return
	var t: TextureRect = _drag["node"]
	if not is_instance_valid(t) or not is_visible_in_tree():
		_cancel_drag()
		return
	if event is InputEventMouseMotion:
		if not _drag["moved"] and event.global_position.distance_to(_drag["from"]) > 6.0:
			_drag["moved"] = true
			t.z_index = 40
			drag_started.emit()
			Audio.play("click")
		if _drag["moved"]:
			t.global_position = event.global_position - _drag["grab"]
			_update_target(event.global_position)
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		get_viewport().set_input_as_handled()
		var target: Dictionary = _drag["target"]
		var uid: int = _drag["uid"]
		var moved: bool = _drag["moved"]
		_end_visuals()
		_drag = {}
		set_process_input(false)
		if not moved:
			return
		if target.get("tray", false):
			if tray_drop.is_valid() and tray_drop.call(uid):
				t.position = target["start"]
				t.visible = false
			else:
				_fly_back(t, target["start"])
		elif target.get("ok", false) and GameState.move_piece(place_id, uid, 0, target["x"], target["y"]):
			Audio.play("shelf")
		else:
			if not target.is_empty():
				Audio.play("error")
			_fly_back(t, target.get("start", t.position))


func _fly_back(t: TextureRect, pos: Vector2) -> void:
	var tw := create_tween()
	tw.tween_property(t, "position", pos, 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func _end_visuals() -> void:
	var t: TextureRect = _drag["node"]
	if is_instance_valid(t):
		t.z_index = 0
	_drag["target"]["start"] = _drag["start"]
	_target = Rect2()
	queue_redraw()
	drag_finished.emit()


func _cancel_drag() -> void:
	var t: TextureRect = _drag.get("node")
	var start: Vector2 = _drag.get("start", Vector2.ZERO)
	_end_visuals()
	if is_instance_valid(t):
		t.position = start
	_drag = {}
	set_process_input(false)


## Snaps the dragged piece to the nearest cells (or sees that it is over the sale tray).
func _update_target(mouse: Vector2) -> void:
	var id: String = _drag["id"]
	var state: int = tray_state.call(id, mouse) if tray_state.is_valid() else 0
	if state != 0:
		_drag["target"] = {"tray": true}
		_target = Rect2()
		queue_redraw()
		return
	var g := _grid()
	var t: TextureRect = _drag["node"]
	var sz := Storage.size_of(id)
	var top_left := (t.global_position - global_position) / cell
	var x := clampi(roundi(top_left.x), 0, g["cols"] - sz.x)
	var y := clampi(roundi(top_left.y), 0, g["rows"] - sz.y)
	var list := GameState.storage.pieces(place_id)
	var index := -1
	for i in list.size():
		if list[i]["uid"] == _drag["uid"]:
			index = i
	var centre := top_left + Vector2(sz) / 2.0
	var near := Rect2(Vector2(-1, -1), Vector2(g["cols"] + 2, g["rows"] + 2)).has_point(centre)
	var ok := near and Storage.fits(place_id, list, id, 0, x, y, index)
	_drag["target"] = {"x": x, "y": y, "ok": ok} if near else {}
	_target = Rect2(Vector2(x, y) * cell, Vector2(sz) * cell) if near else Rect2()
	_target_ok = ok
	queue_redraw()
