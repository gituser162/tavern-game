extends Control
## The attic as a big puzzle grid in its own window, drawn like the shelves under the counter (2026-11-10):
## the same 8 px pixel sprites (shelf_items.png) at the same scale as the shelves, a wooden wall behind them and a
## floor plank under them; the cell grid shows only while a piece is dragged. Pieces can be turned (right click,
## or R / right click / wheel while dragging). A piece can be dragged to another free spot, onto the sale tray, or
## out of the window onto a shelf under the counter; shelf pieces can be dropped here too (main.gd calls
## drop_target / show_target). main.gd gives the callables below.

signal hovered(item_id: String, source: Control, uid: int)
signal drag_started
signal drag_finished

const GameData := preload("res://scripts/game_data.gd")
const Storage := preload("res://scripts/storage.gd")

const WALL := Color("2a1c12")
const WALL_LIGHT := Color("33231a")
const WALL_SEAM := Color("150e09")
const BEAM := Color("4c3524")
const BEAM_LIGHT := Color("6a4a30")
const BEAM_DARK := Color("1a0f0a")
## The shelf sprites are unlit (the shelves light them with the fire); up here they get a dim warm light.
const LIGHT := Color(0.86, 0.76, 0.62)

var place_id := "attic"
## Screen px per cell (main.gd sets it to the shelves' cell size: 8 bg px x the background scale).
var cell := 32.0
## (item_id, mouse position) -> int: 0 = the mouse is not over the tray, 1 = the piece can go there, -1 = it cannot.
var tray_state: Callable
## (uid) -> bool: put the piece on the tray; true if it went there.
var tray_drop: Callable
## (item_id, turned) -> Texture2D: the shelf sprite of an item (standing or on its side).
var piece_texture: Callable
## (item_id, turned, node global rect, uid) -> Dictionary: a shelf spot under the dragged piece ({} = none).
var shelf_target: Callable
## (target, uid, turned) -> bool: move the piece onto that shelf spot.
var shelf_drop: Callable
## () -> void: hide the shelf highlight.
var shelf_clear: Callable

var _nodes: Dictionary = {}
var _drag: Dictionary = {}
var _target := Rect2()
var _target_ok := false
## True while a piece from a shelf is dragged over this grid (the grid lines show).
var _outside_drag := false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS
	set_process_input(false)
	refresh()


func _grid() -> Dictionary:
	return Storage.grid_of(place_id)


## Height of the floor plank under the grid (screen px).
func _floor() -> float:
	return roundf(cell / 8.0) * 3.0


func refresh() -> void:
	var g := _grid()
	custom_minimum_size = Vector2(g["cols"] * cell, g["rows"] * cell + _floor())
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
		var turned: bool = p.get("r", false)
		if t.get_meta("r", false) != turned:
			_set_look(t, p["id"], turned)
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


func _set_look(t: TextureRect, id: String, turned: bool) -> void:
	t.set_meta("r", turned)
	var tex: Texture2D = piece_texture.call(id, turned) if piece_texture.is_valid() else null
	if tex == null:
		tex = GameData.icon_texture(id)
		t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	else:
		t.stretch_mode = TextureRect.STRETCH_SCALE
	t.texture = tex


func _make_piece(p: Dictionary) -> TextureRect:
	var t := TextureRect.new()
	var id: String = p["id"]
	var uid: int = p["uid"]
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	t.self_modulate = LIGHT
	t.mouse_filter = Control.MOUSE_FILTER_STOP
	t.mouse_default_cursor_shape = Control.CURSOR_DRAG
	_set_look(t, id, p.get("r", false))
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
	var px := roundf(cell / 8.0)   # one background pixel
	var area := Vector2(cols, rows) * cell
	# Back wall of the attic: vertical boards (2 cells wide) with dark seams and a few knots.
	draw_rect(Rect2(Vector2.ZERO, area), WALL)
	var board := cell * 2.0
	var bx := 0.0
	var i := 0
	while bx < area.x:
		if i % 2 == 1:
			draw_rect(Rect2(bx, 0, minf(board, area.x - bx), area.y), WALL_LIGHT)
		draw_rect(Rect2(bx, 0, px, area.y), WALL_SEAM)
		var knot_y := fmod(37.0 * (i + 1), maxf(area.y - px * 3.0, 1.0))
		draw_rect(Rect2(bx + board * 0.5, knot_y, px * 2.0, px), WALL_SEAM)
		bx += board
		i += 1
	# A beam across the top, like the shelf above.
	draw_rect(Rect2(0, 0, area.x, px * 2.0), BEAM_DARK)
	# Floor plank under everything: lit top edge, dark bottom (like the shelf planks).
	var fy := area.y
	draw_rect(Rect2(0, fy, area.x, _floor()), BEAM)
	draw_rect(Rect2(0, fy, area.x, px), BEAM_LIGHT)
	draw_rect(Rect2(0, fy + _floor() - px, area.x, px), BEAM_DARK)
	# The cell grid shows only while something is dragged (as on the shelves).
	if not _drag.is_empty() or _outside_drag:
		var line := Color(1, 0.9, 0.7, 0.12)
		for x in cols + 1:
			draw_line(Vector2(x * cell, 0), Vector2(x * cell, area.y), line, 1.0)
		for y in rows + 1:
			draw_line(Vector2(0, y * cell), Vector2(area.x, y * cell), line, 1.0)
	if _target.size.x > 0:
		var col := Color(0.45, 0.9, 0.4) if _target_ok else Color(0.95, 0.35, 0.3)
		draw_rect(_target, Color(col, 0.25))
		draw_rect(_target, col, false, 2.0)


# --- a piece from a shelf dragged over the attic (main.gd) ---

## Where a piece whose top-left corner is at `global_top_left` would land here: {"x", "y", "ok"}, or {} if it is not
## over the grid. Also shows the highlight.
func drop_target(id: String, turned: bool, global_top_left: Vector2, uid: int) -> Dictionary:
	var g := _grid()
	var sz := Storage.size_of(id, turned)
	var top_left := (global_top_left - global_position) / cell
	var centre := top_left + Vector2(sz) / 2.0
	if not is_visible_in_tree() or not Rect2(Vector2(-0.5, -0.5), Vector2(g["cols"] + 1, g["rows"] + 1)).has_point(centre):
		show_target({})
		return {}
	var x := clampi(roundi(top_left.x), 0, g["cols"] - sz.x)
	var y := clampi(roundi(top_left.y), 0, g["rows"] - sz.y)
	var list := GameState.storage.pieces(place_id)
	var index := -1
	for i in list.size():
		if list[i]["uid"] == uid:
			index = i
	var t := {"x": x, "y": y, "ok": Storage.fits(place_id, list, id, 0, x, y, index, turned), "w": sz.x, "h": sz.y}
	show_target(t)
	return t


## Highlights a spot ({} = none).
func show_target(t: Dictionary) -> void:
	_outside_drag = not t.is_empty()
	if t.is_empty():
		_target = Rect2()
	else:
		_target = Rect2(Vector2(t["x"], t["y"]) * cell, Vector2(t["w"], t["h"]) * cell)
		_target_ok = t["ok"]
	queue_redraw()


# --- dragging ---

func _on_piece_input(event: InputEvent, uid: int, id: String, t: TextureRect) -> void:
	if not (event is InputEventMouseButton and event.pressed) or not _drag.is_empty():
		return
	if event.button_index == MOUSE_BUTTON_RIGHT:
		t.accept_event()
		_turn_in_place(uid, id)
		return
	if event.button_index != MOUSE_BUTTON_LEFT:
		return
	var r: bool = t.get_meta("r", false)
	_drag = {"uid": uid, "id": id, "node": t, "grab": event.global_position - t.global_position,
		"from": event.global_position, "start": t.position, "moved": false, "target": {}, "r": r, "r0": r}
	t.accept_event()
	set_process_input(true)
	queue_redraw()


## Right click on a resting piece: turn it where it lies, or in the nearest free spot next to it.
func _turn_in_place(uid: int, id: String) -> void:
	var list := GameState.storage.pieces(place_id)
	var index := -1
	for i in list.size():
		if list[i]["uid"] == uid:
			index = i
	if index < 0:
		return
	var p: Dictionary = list[index]
	var turned: bool = not p.get("r", false)
	var before := Storage.piece_size(p)
	var after := Storage.size_of(id, turned)
	if before == after:
		return
	var g := _grid()
	var anchor := Vector2(p["x"], p["y"] + before.y - after.y)
	var best := Vector2i(-1, -1)
	var best_d := 2.5
	for y in g["rows"] - after.y + 1:
		for x in g["cols"] - after.x + 1:
			var d := anchor.distance_to(Vector2(x, y))
			if d < best_d and Storage.fits(place_id, list, id, 0, x, y, index, turned):
				best_d = d
				best = Vector2i(x, y)
	if best.x >= 0 and GameState.move_piece(place_id, uid, 0, best.x, best.y, turned):
		Audio.play("shelf")
	else:
		Audio.play("error")


func _turn_dragged() -> void:
	var t: TextureRect = _drag["node"]
	var mouse: Vector2 = t.global_position + _drag["grab"]
	var rel: Vector2 = _drag["grab"] / t.size if t.size.x > 0 and t.size.y > 0 else Vector2(0.5, 0.5)
	_drag["r"] = not _drag["r"]
	_set_look(t, _drag["id"], _drag["r"])
	t.size = Vector2(Storage.size_of(_drag["id"], _drag["r"])) * cell
	_drag["grab"] = Vector2(rel.y, rel.x) * t.size
	t.global_position = mouse - _drag["grab"]
	if not _drag["moved"]:
		_drag["moved"] = true
		t.z_index = 40
		drag_started.emit()
	Audio.play("click")
	_update_target(mouse)


func _input(event: InputEvent) -> void:
	if _drag.is_empty():
		set_process_input(false)
		return
	var t: TextureRect = _drag["node"]
	if not is_instance_valid(t) or not is_visible_in_tree():
		_cancel_drag()
		return
	var turn_key: bool = event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_R
	var turn_mouse: bool = event is InputEventMouseButton and event.pressed and event.button_index in [MOUSE_BUTTON_RIGHT, MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]
	if turn_key or turn_mouse:
		get_viewport().set_input_as_handled()
		if Storage.size_of(_drag["id"]) != Storage.size_of(_drag["id"], true):
			_turn_dragged()
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
		var turned: bool = _drag["r"]
		var turned0: bool = _drag["r0"]
		var id: String = _drag["id"]
		_end_visuals()
		_drag = {}
		set_process_input(false)
		if not moved:
			return
		if target.get("tray", false):
			if tray_drop.is_valid() and tray_drop.call(uid):
				_restore_look(t, id, turned, turned0, target["start"])
				t.visible = false
			else:
				_fly_back(t, id, turned, turned0, target["start"])
		elif target.get("shelf", false):
			if target["ok"] and shelf_drop.is_valid() and shelf_drop.call(target, uid, turned):
				Audio.play("shelf")
			else:
				Audio.play("error")
				_fly_back(t, id, turned, turned0, target["start"])
		elif target.get("ok", false) and GameState.move_piece(place_id, uid, 0, target["x"], target["y"], turned):
			Audio.play("shelf")
		else:
			if target.has("x"):
				Audio.play("error")
			_fly_back(t, id, turned, turned0, target.get("start", t.position))


func _restore_look(t: TextureRect, id: String, turned: bool, turned0: bool, pos: Vector2) -> void:
	if turned != turned0:
		_set_look(t, id, turned0)
		t.size = Vector2(Storage.size_of(id, turned0)) * cell
	t.position = pos


func _fly_back(t: TextureRect, id: String, turned: bool, turned0: bool, pos: Vector2) -> void:
	if turned != turned0:
		_set_look(t, id, turned0)
		t.size = Vector2(Storage.size_of(id, turned0)) * cell
	var tw := create_tween()
	tw.tween_property(t, "position", pos, 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func _end_visuals() -> void:
	var t: TextureRect = _drag["node"]
	if is_instance_valid(t):
		t.z_index = 0
	_drag["target"]["start"] = _drag["start"]
	_target = Rect2()
	_outside_drag = false
	if shelf_clear.is_valid():
		shelf_clear.call()
	queue_redraw()
	drag_finished.emit()


func _cancel_drag() -> void:
	var t: TextureRect = _drag.get("node")
	var start: Vector2 = _drag.get("start", Vector2.ZERO)
	var id: String = _drag.get("id", "")
	var turned: bool = _drag.get("r", false)
	var turned0: bool = _drag.get("r0", false)
	_end_visuals()
	if is_instance_valid(t):
		_restore_look(t, id, turned, turned0, start)
	_drag = {}
	set_process_input(false)


## Snaps the dragged piece to the nearest cells, or sees that it is over the sale tray or a shelf.
func _update_target(mouse: Vector2) -> void:
	var id: String = _drag["id"]
	var turned: bool = _drag["r"]
	var state: int = tray_state.call(id, mouse) if tray_state.is_valid() else 0
	if state != 0:
		_drag["target"] = {"tray": true}
		_target = Rect2()
		if shelf_clear.is_valid():
			shelf_clear.call()
		queue_redraw()
		return
	var g := _grid()
	var t: TextureRect = _drag["node"]
	var sz := Storage.size_of(id, turned)
	var top_left := (t.global_position - global_position) / cell
	var centre := top_left + Vector2(sz) / 2.0
	var near := Rect2(Vector2(-1, -1), Vector2(g["cols"] + 2, g["rows"] + 2)).has_point(centre)
	if not near:
		_target = Rect2()
		queue_redraw()
		var st: Dictionary = shelf_target.call(id, turned, t.get_global_rect(), _drag["uid"]) if shelf_target.is_valid() else {}
		if not st.is_empty():
			st["shelf"] = true
		_drag["target"] = st
		return
	if shelf_clear.is_valid():
		shelf_clear.call()
	var x := clampi(roundi(top_left.x), 0, g["cols"] - sz.x)
	var y := clampi(roundi(top_left.y), 0, g["rows"] - sz.y)
	var list := GameState.storage.pieces(place_id)
	var index := -1
	for i in list.size():
		if list[i]["uid"] == _drag["uid"]:
			index = i
	var ok := Storage.fits(place_id, list, id, 0, x, y, index, turned)
	_drag["target"] = {"x": x, "y": y, "ok": ok}
	_target = Rect2(Vector2(x, y) * cell, Vector2(sz) * cell)
	_target_ok = ok
	queue_redraw()
