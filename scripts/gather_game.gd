extends Control
## Gathering mini-game: a click on a resource in a location opens a close-up of it, and the resource has to be
## taken with its own little gesture (GameData.GATHER_KINDS / GATHER):
##   "pull"     - herbs, roots, moss, weed: hold the button and pull up gently, too fast and the stem snaps;
##   "mandrake" - like "pull", but freeze while the mandrake shrieks;
##   "shake"    - berries: click to shake the bush and catch the falling berries with the basket;
##   "dig"      - bones, grave dust: click to dig, and as soon as something shows, stop and brush it off with
##                the cursor (one more stroke of the shovel cracks it);
##   "catch"    - toad, crayfish, ether essence: click it while it sits still, it gets away after 3 misses.
## The result is emitted as finished(pieces): 2 = a great job (an extra piece), 1 = taken, 0 = spoiled / gone,
## -1 = the player left it alone (nothing changes). The scene is drawn in pixels (W x H) like fishing_game.gd.

signal finished(pieces: int)

const GameData := preload("res://scripts/game_data.gd")

enum Step { PLAY, RESULT }

const W := 160
const H := 90
## The ground line of the close-up (scene pixels).
const GROUND := 62
const GOLD := Color("f2c14e")
const TEXT := Color("eadbc8")
const MUTED := Color("b8a48c")
const BAD := Color("e08a7a")
## The tension bar of the pull games (scene pixels).
const BAR_X := 146
const BAR_TOP := 12
const BAR_H := 56
## Colours of the close-up per location: backdrop, backdrop details, grass, soil, deep soil.
const PALETTES := {
	"forest": ["1c3322", "2a4a2c", "4f7a35", "4a3222", "35241a"],
	"graveyard": ["20262e", "2e3640", "4a5a3a", "3d3229", "2a221c"],
	"swamp": ["1b2620", "2a3a2c", "4a5e32", "35302a", "24211c"],
	"lake": ["2c4a5e", "3a6278", "c2a66b", "8f7448", "6b5636"],
}

var _scene: Control
var _title: Label
var _hint: Label
var _close: Button

var _step: Step = Step.PLAY
var _item: String = ""
var _kind: String = ""
var _pal: Array = []
var _tex: Texture2D
## Seconds in the current step, and since the window was opened.
var _t: float = 0.0
var _time: float = 0.0
var _pieces: int = 0
var _result_text: String = ""
var _mouse := Vector2(80, 45)
var _last_mouse := Vector2(80, 45)
var _holding: bool = false
## Flying dirt, drops and sparkles: {"p", "v", "life", "c"}.
var _bits: Array = []
## Grass blades and pebbles of the close-up (rolled once per opening).
var _deco: Array = []

# --- pull / mandrake ---
var _lift: float = 0.0
var _speed: float = 0.0
var _tension: float = 0.0
var _peak: float = 0.0
var _grip_phase: float = 0.0
## Mandrake: seconds until the next shriek, and the shriek itself (> 0 while it shrieks).
var _shriek_in: float = 0.0
var _shriek: float = 0.0

# --- shake ---
var _berries: Array = []
var _to_drop: int = 0
var _caught: int = 0
var _basket_x: float = 80.0
var _shake: float = 0.0
var _cool: float = 0.0

# --- dig ---
var _layers: int = 0
var _dug: int = 0
var _brush: float = 0.0
var _cracked: bool = false

# --- catch ---
var _pos := Vector2(80, 60)
var _from := Vector2(80, 60)
var _to := Vector2(80, 60)
var _hop: float = -1.0
var _sit: float = 0.0
var _hops: int = 0
var _misses: int = 0
var _flash: float = 0.0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.085, 0.05, 0.03, 0.97)
	style.border_color = Color("6b4a2f")
	style.set_border_width_all(3)
	style.set_corner_radius_all(6)
	style.set_content_margin_all(16)
	panel.add_theme_stylebox_override("panel", style)
	center.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	panel.add_child(box)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 16)
	box.add_child(head)
	_title = Label.new()
	_title.add_theme_font_size_override("font_size", 22)
	_title.add_theme_color_override("font_color", GOLD)
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(_title)
	_close = Button.new()
	_close.text = "Облишити"
	_close.focus_mode = Control.FOCUS_NONE
	_close.tooltip_text = "Залишити ресурс на місці (його можна спробувати ще раз)"
	_close.pressed.connect(_cancel)
	head.add_child(_close)
	_scene = Control.new()
	_scene.custom_minimum_size = Vector2(W, H) * 4.5
	_scene.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_scene.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_scene.draw.connect(_draw_scene)
	_scene.gui_input.connect(_on_scene_input)
	box.add_child(_scene)
	_hint = Label.new()
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hint.custom_minimum_size = Vector2(W * 4.5, 48)
	_hint.add_theme_font_size_override("font_size", 17)
	_hint.add_theme_color_override("font_color", TEXT)
	box.add_child(_hint)
	set_process(false)


## The kind of mini-game for this item ("" = it is just picked up with a click).
static func kind_of(item: String) -> String:
	return GameData.GATHER_KINDS.get(item, "")


## Opens the close-up of "item" lying in location "location".
func open(item: String, location: String) -> void:
	_item = item
	_kind = kind_of(item)
	_pal = PALETTES.get(location, PALETTES["forest"])
	_tex = GameData.icon_texture(item)
	_step = Step.PLAY
	_t = 0.0
	_pieces = 0
	_result_text = ""
	_holding = false
	_bits.clear()
	_deco.clear()
	for i in 26:
		_deco.append(Vector3(randf_range(2, 140), randf_range(0, 1), randi() % 3))
	_title.text = GameData.ITEMS[item]["name"]
	_close.disabled = false
	var g: Dictionary = GameData.GATHER
	match _kind:
		"pull", "mandrake":
			_lift = 0.0
			_speed = 0.0
			_tension = 0.0
			_peak = 0.0
			_grip_phase = randf() * TAU
			_shriek = 0.0
			_shriek_in = randf_range(g["shriek_every"][0], g["shriek_every"][1])
			_hint.text = "Затисни кнопку й тягни вгору, але плавно: якщо смикнеш, стебло обірветься. Стеж за смужкою праворуч."
			if _kind == "mandrake":
				_hint.text += " Коли мандрагора кричить, завмри!"
		"shake":
			_berries.clear()
			_to_drop = int(g["berries"])
			_caught = 0
			_basket_x = 80.0
			_shake = 0.0
			_cool = 0.0
			_hint.text = "Клацай по кущу, щоб струсити ягоди, і лови їх кошиком (він ходить за курсором)."
		"dig":
			_layers = randi_range(g["dig_layers"][0], g["dig_layers"][1])
			_dug = 0
			_brush = 0.0
			_cracked = false
			_hint.text = "Клацай, щоб копати. Щойно щось забіліє, більше не копай: змети землю, водячи по знахідці курсором."
		"catch":
			_misses = 0
			_hops = 0
			_flash = 0.0
			_pos = _catch_spot()
			_to = _pos
			_from = _pos
			_hop = -1.0
			_sit = float(g["sit_start"])
			_hint.text = "Клацни по ньому, поки сидить на місці. Три промахи, і втече."
			if _item == "ether_essence":
				_hint.text = "Клацни по есенції, коли вона яскраво світиться. Три промахи, і вона розвіється."
	visible = true
	set_process(true)
	_scene.queue_redraw()


func _cancel() -> void:
	if _step == Step.RESULT:
		_finish()
		return
	visible = false
	set_process(false)
	finished.emit(-1)


func _finish() -> void:
	visible = false
	set_process(false)
	finished.emit(_pieces)


func _end(pieces: int, text: String) -> void:
	if _step == Step.RESULT:
		return
	_step = Step.RESULT
	_t = 0.0
	_pieces = pieces
	_result_text = text
	_holding = false
	_close.disabled = true
	_hint.text = text
	if pieces >= 2:
		Audio.play("magic")
		for i in 14:
			_bits.append({"p": Vector2(80, 40), "v": Vector2.from_angle(randf() * TAU) * randf_range(20, 50),
				"life": randf_range(0.5, 1.0), "c": GOLD})
	elif pieces == 0:
		Audio.play("fail")


func _unhandled_input(event: InputEvent) -> void:
	if visible and event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		_cancel()
		get_viewport().set_input_as_handled()


func _input(event: InputEvent) -> void:
	# Releasing the button outside the scene still counts.
	if visible and event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		_holding = false


func _on_scene_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT):
		return
	_holding = event.pressed
	if not event.pressed:
		return
	_mouse = _to_scene(event.position)
	_last_mouse = _mouse
	if _step == Step.RESULT:
		if _t > 0.5:
			_finish()
		return
	match _kind:
		"shake":
			_shake_bush()
		"dig":
			_dig()
		"catch":
			_try_catch()


func _to_scene(p: Vector2) -> Vector2:
	return (p - _offset()) / _scale()


func _process(delta: float) -> void:
	_time += delta
	_t += delta
	_last_mouse = _mouse
	_mouse = _to_scene(_scene.get_local_mouse_position())
	for b in _bits:
		b["p"] += b["v"] * delta
		b["v"].y += 90.0 * delta
		b["life"] -= delta
	_bits = _bits.filter(func(b): return b["life"] > 0.0)
	if _step == Step.RESULT:
		if _t > 1.8:
			_finish()
		_scene.queue_redraw()
		return
	match _kind:
		"pull", "mandrake":
			_process_pull(delta)
		"shake":
			_process_shake(delta)
		"dig":
			_process_dig(delta)
		"catch":
			_process_catch(delta)
	_scene.queue_redraw()


# --- pull -------------------------------------------------------------------------------------------------

## How fast the plant can be pulled right now before it snaps (scene pixels a second): the root grips and lets go.
func _grip_limit() -> float:
	var g: Dictionary = GameData.GATHER
	return float(g["pull_snap_speed"]) * (0.75 + 0.25 * sin(_t * 2.3 + _grip_phase))


func _process_pull(delta: float) -> void:
	var g: Dictionary = GameData.GATHER
	var up := 0.0
	if _holding:
		up = maxf(0.0, _last_mouse.y - _mouse.y)
	var raw := up / maxf(delta, 0.001)
	_speed = lerpf(_speed, raw, 1.0 - exp(-12.0 * delta))
	_tension = _speed / _grip_limit()
	if _holding:
		_lift += up / float(g["pull_dist"])
	else:
		_lift = maxf(0.0, _lift - float(g["pull_back"]) * delta)  # the root pulls it back into the ground
	_peak = maxf(_peak, _tension)
	if _kind == "mandrake":
		if _shriek > 0.0:
			_shriek -= delta
			if _holding and _speed > float(g["shriek_still"]):
				_end(0, "Мандрагора закричала, а ти смикнув! Вона вислизнула з рук і зарилася назад у землю.")
				return
			if _shriek <= 0.0:
				_shriek_in = randf_range(g["shriek_every"][0], g["shriek_every"][1])
		else:
			_shriek_in -= delta
			if _shriek_in <= 0.0:
				_shriek = float(g["shriek_time"])
				Audio.play("angry")
	if _tension > 1.0:
		for i in 8:
			_bits.append({"p": Vector2(80, GROUND - 6), "v": Vector2(randf_range(-30, 30), randf_range(-50, -15)),
				"life": randf_range(0.4, 0.8), "c": Color(_pal[2])})
		_end(0, "Ти смикнув занадто різко, і стебло обірвалося. Корінь лишився в землі.")
		return
	if _lift >= 1.0:
		if _t <= float(g["pull_great_time"]) and _peak < 0.85:
			_end(2, "Ідеально! Витягнув цілим, разом із корінням: +2.")
		else:
			_end(1, "Витягнув. Трохи пом'яв, але згодиться: +1.")


# --- shake ------------------------------------------------------------------------------------------------

func _shake_bush() -> void:
	if _cool > 0.0 or _to_drop <= 0:
		return
	_cool = float(GameData.GATHER["shake_cooldown"])
	_shake = 0.3
	_to_drop -= 1
	Audio.play("click")
	_berries.append({"p": Vector2(randf_range(36, 124), randf_range(22, 34)), "v": Vector2(randf_range(-14, 14), 0),
		"state": "fall", "t": 0.0})


func _process_shake(delta: float) -> void:
	var g: Dictionary = GameData.GATHER
	_cool = maxf(0.0, _cool - delta)
	_shake = maxf(0.0, _shake - delta)
	var target := clampf(_mouse.x, 12.0, 136.0)
	_basket_x = move_toward(_basket_x, target, float(g["basket_speed"]) * delta)
	var falling := 0
	for b in _berries:
		if b["state"] == "fall":
			falling += 1
			b["v"].y += 120.0 * delta
			b["p"] += b["v"] * delta
			if b["p"].y >= 74.0:
				if absf(b["p"].x - _basket_x) <= 10.0:
					b["state"] = "caught"
					_caught += 1
					Audio.play("gather")
				else:
					b["state"] = "lost"
					b["v"] = Vector2(signf(b["v"].x + 0.01) * 20.0, -20.0)
		elif b["state"] == "lost":
			b["t"] += delta
			b["v"].y += 120.0 * delta
			b["p"] += b["v"] * delta
			b["p"].y = minf(b["p"].y, 80.0)
	if _to_drop <= 0 and falling == 0 and _cool <= 0.0:
		var total := int(g["berries"])
		if _caught >= total - 1:
			_end(2, "Майже всі ягоди в кошику: +2.")
		elif _caught >= 2:
			_end(1, "Частина ягід розкотилася в траві, але щось є: +1.")
		else:
			_end(0, "Ягоди розсипалися в траву й розчавилися. Нічого не зібрав.")


# --- dig --------------------------------------------------------------------------------------------------

func _dig() -> void:
	if _dug >= _layers:
		_cracked = true
		Audio.play("dig")
		_end(1, "Лопата дзенькнула об знахідку й надколола її. Узяв, що лишилося: +1.")
		return
	_dug += 1
	Audio.play("dig")
	for i in 7:
		_bits.append({"p": Vector2(80 + randf_range(-8, 8), GROUND + 2), "v": Vector2(randf_range(-40, 40), randf_range(-60, -25)),
			"life": randf_range(0.4, 0.8), "c": Color(_pal[3]) if i % 2 == 0 else Color(_pal[4])})


func _process_dig(_delta: float) -> void:
	if _dug < _layers:
		return
	# Brushing: moving the cursor over the find sweeps the earth away.
	if Rect2(60, GROUND - 4, 40, 26).has_point(_mouse):
		var d := _mouse.distance_to(_last_mouse)
		_brush += d / float(GameData.GATHER["brush_dist"])
		if d > 1.0 and randf() < 0.3:
			_bits.append({"p": _mouse, "v": Vector2(randf_range(-20, 20), randf_range(-25, -5)), "life": 0.4, "c": Color(_pal[3])})
	if _brush >= 1.0:
		_end(2, "Обережно змів землю, знахідка ціла: +2.")


# --- catch ------------------------------------------------------------------------------------------------

func _catch_spot() -> Vector2:
	if _item == "ether_essence":
		return Vector2(randf_range(24, 124), randf_range(18, 52))
	return Vector2(randf_range(20, 128), randf_range(GROUND + 4, 80))


func _sitting() -> bool:
	if _item == "ether_essence":
		return sin(_t * 2.6) > 0.25  # it glows brightly
	return _hop < 0.0


func _try_catch() -> void:
	var g: Dictionary = GameData.GATHER
	var near := _mouse.distance_to(_pos - Vector2(0, 5)) <= float(g["catch_radius"])
	if near and _sitting():
		if _misses == 0:
			_end(2, "Спритно! Схопив з першого разу, а поруч сидів ще один: +2." if _item != "ether_essence" else "Есенція сама влилася в пляшечку, ще й густа: +2.")
		else:
			_end(1, "Впіймав: +1.")
		return
	_misses += 1
	_flash = 0.3
	Audio.play("error")
	if _misses >= int(g["catch_misses"]):
		_end(0, "Втекло! Тепер його вже не знайти." if _item != "ether_essence" else "Есенція розвіялася в повітрі.")
		return
	_jump()


func _jump() -> void:
	_from = _pos
	_to = _catch_spot()
	_hop = 0.0
	_hops += 1


func _process_catch(delta: float) -> void:
	var g: Dictionary = GameData.GATHER
	_flash = maxf(0.0, _flash - delta)
	if _item == "ether_essence":
		# It drifts in slow loops and flares up now and then.
		_pos = Vector2(80 + 50 * sin(_t * 0.9), 36 + 14 * sin(_t * 1.7 + 0.6))
		if _t > float(g["catch_time"]):
			_end(0, "Есенція розвіялася в повітрі.")
		return
	if _hop >= 0.0:
		_hop += delta / 0.45
		var k := minf(_hop, 1.0)
		var arc := 0.0 if _item == "crayfish" else sin(k * PI) * 16.0
		_pos = _from.lerp(_to, k) - Vector2(0, arc)
		if _hop >= 1.0:
			_pos = _to
			_hop = -1.0
			_sit = maxf(float(g["sit_min"]), float(g["sit_start"]) - _hops * 0.08) * randf_range(0.8, 1.2)
	else:
		_sit -= delta
		if _sit <= 0.0:
			if _hops >= int(g["catch_hops"]):
				_end(0, "Застрибало в кущі й зникло." if _item == "toad" else "Сховалося під камінь, і вже не дістанеш.")
				return
			_jump()


# --- drawing ----------------------------------------------------------------------------------------------

func _scale() -> float:
	return floorf(minf(_scene.size.x / W, _scene.size.y / H) * 2.0) / 2.0


func _offset() -> Vector2:
	return (_scene.size - Vector2(W, H) * _scale()) / 2.0


func _px(x: float, y: float, w: float, h: float, c: Color) -> void:
	_scene.draw_rect(Rect2(floorf(x), floorf(y), w, h), c)


## A round pixel blob (rows of 1px), for bushes.
func _blob(cx: float, cy: float, r: float, col: Color) -> void:
	for y in range(int(-r), int(r) + 1):
		var w := floorf(sqrt(maxf(0.0, r * r - y * y)))
		_px(cx - w, cy + y, w * 2.0, 1, col)


func _icon(center: Vector2, size: float, mod: Color = Color.WHITE) -> void:
	if _tex:
		_scene.draw_texture_rect(_tex, Rect2((center - Vector2(size, size) / 2.0).floor(), Vector2(size, size)), false, mod)


func _draw_scene() -> void:
	if _pal.is_empty():
		return
	_scene.draw_set_transform(_offset(), 0.0, Vector2.ONE * _scale())
	var shake := Vector2.ZERO
	if _kind == "mandrake" and _shriek > 0.0:
		shake = Vector2(randf_range(-1, 1), randf_range(-1, 1)).round()
	_scene.draw_set_transform(_offset() + shake * _scale(), 0.0, Vector2.ONE * _scale())
	_draw_backdrop()
	match _kind if _step == Step.PLAY else "":
		"pull", "mandrake":
			_draw_pull()
		"shake":
			_draw_shake()
		"dig":
			_draw_dig()
		"catch":
			_draw_catch()
	for b in _bits:
		var c: Color = b["c"]
		c.a = clampf(b["life"] * 2.0, 0.0, 1.0)
		_px(b["p"].x, b["p"].y, 1, 1, c)
	if _step == Step.RESULT:
		_draw_result()
	_scene.draw_set_transform(Vector2.ZERO)


func _draw_backdrop() -> void:
	var back := Color(_pal[0])
	var det := Color(_pal[1])
	_px(0, 0, W, GROUND, back)
	# Distant shapes: bushes, stones or waves, depending on the palette.
	for i in 9:
		var x := i * 19.0 - 6.0
		var hh := 10.0 + float((i * 7) % 5) * 3.0
		_px(x, GROUND - hh, 15, hh, det)
		_px(x + 3, GROUND - hh - 3, 9, 3, det)
	_px(0, GROUND, W, H - GROUND, Color(_pal[3]))
	_px(0, GROUND + 14, W, H - GROUND - 14, Color(_pal[4]))
	_px(0, GROUND - 1, W, 2, Color(_pal[2]))
	for d: Vector3 in _deco:
		var x: float = d.x
		if d.z == 2:
			_px(x, GROUND + 6 + d.y * 18, 3, 2, Color(_pal[4]).lightened(0.15))  # pebble
		else:
			var h := 2.0 + d.y * 4.0
			_px(x, GROUND - h, 1, h, Color(_pal[2]).lightened(0.1 * d.z))


## A bar on the right: how hard the plant is pulled (red at the top = it snaps).
func _draw_tension() -> void:
	_px(BAR_X - 1, BAR_TOP - 1, 7, BAR_H + 2, Color("1a0f0a"))
	for i in BAR_H:
		var k := 1.0 - float(i) / BAR_H
		var c := Color("6aa84a")
		if k > 0.85:
			c = Color("c8452e")
		elif k > 0.6:
			c = Color("d9a83a")
		_px(BAR_X, BAR_TOP + i, 5, 1, c.darkened(0.55))
	var fill := clampf(_tension, 0.0, 1.0) * BAR_H
	for i in int(fill):
		var k := float(i) / BAR_H
		var c := Color("6aa84a") if k < 0.6 else (Color("d9a83a") if k < 0.85 else Color("e8553a"))
		_px(BAR_X, BAR_TOP + BAR_H - 1 - i, 5, 1, c)
	# Progress: how far the root is out.
	_px(8, 82, 120, 4, Color("1a0f0a"))
	_px(9, 83, 118 * clampf(_lift, 0.0, 1.0), 2, GOLD)


func _draw_pull() -> void:
	var up := clampf(_lift, 0.0, 1.0) * 30.0
	var jitter := 0.0
	if _tension > 0.65:
		jitter = roundf(sin(_time * 40.0)) * 1.0
	var c := Vector2(80 + jitter, GROUND - 6 - up)
	# Root strands stretched into the soil while it is still in the ground.
	if _lift < 1.0:
		for i in 3:
			var x := c.x - 4 + i * 4
			var a := Vector2(x, c.y + 8)
			var b := Vector2(80 - 6 + i * 6, GROUND + 10)
			var n := int(b.y - a.y)
			for k in n:
				var f := float(k) / maxf(1.0, n)
				_px(lerpf(a.x, b.x, f) + roundf(sin(k * 0.9 + i) * 0.6), a.y + k, 1, 1, Color("6e5236"))
	_icon(c, 22)
	# The soil covers the bottom of the plant (drawn again over it), with a little mound.
	_px(0, GROUND + 4, W, 10, Color(_pal[3]))
	_px(68, GROUND, 24, 4, Color(_pal[3]).lightened(0.08))
	_px(72, GROUND - 1, 16, 1, Color(_pal[3]).lightened(0.12))
	# The hand on the stem while holding.
	if _holding and _step == Step.PLAY:
		# An arm reaching down from above, the fist round the top of the plant.
		_px(c.x - 4, 0, 9, c.y - 11, Color("6b4a2f"))
		_px(c.x - 4, c.y - 13, 9, 2, Color("8a6440"))
		_px(c.x - 5, c.y - 11, 10, 6, Color("e0b48a"))
		_px(c.x - 5, c.y - 6, 10, 1, Color("b8865e"))
	if _kind == "mandrake":
		var warn := _shriek <= 0.0 and _shriek_in < 0.5
		if warn and fmod(_time, 0.2) < 0.1:
			_px(c.x - 9, c.y - 10, 2, 2, Color(_pal[2]).lightened(0.3))
			_px(c.x + 8, c.y - 10, 2, 2, Color(_pal[2]).lightened(0.3))
		if _shriek > 0.0:
			for i in 3:
				var r := 12.0 + i * 7.0 + fmod(_time * 30.0, 7.0)
				_scene.draw_arc(c, r, -PI * 0.85, -PI * 0.15, 12, Color(1, 0.9, 0.6, 0.6 - i * 0.15), 1.0)
			_px(c.x - 1, c.y - 1, 3, 3, Color("2a0f0a"))  # the open mouth
			_px(60, 6, 40, 9, Color(0, 0, 0, 0.5))
			_px(62, 8, 36, 5, BAD)
	_draw_tension()


func _draw_shake() -> void:
	var sx := roundf(sin(_time * 60.0)) * 2.0 if _shake > 0.0 else 0.0
	# The bush: round leafy blobs (lighter on top) with berries on it.
	var bush := Color(_pal[2]).darkened(0.3)
	for b in [[44, 40, 16], [80, 34, 22], [114, 40, 16], [62, 48, 14], [98, 48, 14]]:
		_blob(b[0] + sx, b[1], b[2], bush.darkened(0.2))
		_blob(b[0] + sx, b[1] - 2, b[2] - 2, bush)
		_blob(b[0] + sx - b[2] * 0.3, b[1] - b[2] * 0.4, b[2] * 0.4, bush.lightened(0.15))
	_px(78 + sx, 50, 4, GROUND - 50, Color("4a3020"))
	for i in _to_drop:
		var p := Vector2(42 + (i * 23) % 76, 26 + (i * 11) % 22)
		_px(p.x + sx, p.y, 3, 3, Color("b8344a"))
		_px(p.x + sx, p.y, 1, 1, Color("ff8aa0"))
	# Berries in the air and on the grass.
	for b in _berries:
		if b["state"] == "caught":
			continue
		var col := Color("b8344a") if b["state"] == "fall" else Color("6a2030")
		_px(b["p"].x - 1, b["p"].y - 1, 2, 2, col)
	# The basket.
	var x := _basket_x
	_px(x - 11, 72, 22, 9, Color("8a5a2e"))
	_px(x - 11, 72, 22, 2, Color("b07a40"))
	for i in 5:
		_px(x - 10 + i * 5, 74, 1, 7, Color("6b4422"))
	_scene.draw_arc(Vector2(x, 72), 9, PI, TAU, 12, Color("6b4422"), 1.0)
	for i in mini(_caught, 6):
		_px(x - 8 + i * 3, 70, 2, 2, Color("b8344a"))
	# Berries left to shake down.
	var total := int(GameData.GATHER["berries"])
	for i in total:
		var c := Color("b8344a") if i < _to_drop else Color("3a2a2a")
		_px(4 + i * 4, 4, 3, 3, c)


func _draw_dig() -> void:
	var depth := float(_dug) / maxf(1.0, float(_layers))
	var hole := Rect2(62, GROUND, 36, 4 + depth * 16)
	_px(hole.position.x, hole.position.y, hole.size.x, hole.size.y, Color(_pal[4]).darkened(0.35))
	# A pile of dug earth on the side.
	var pile := 2.0 + _dug * 2.0
	_px(102, GROUND - pile, 20, pile, Color(_pal[3]).lightened(0.05))
	_px(106, GROUND - pile - 2, 12, 2, Color(_pal[3]).lightened(0.1))
	if _dug >= _layers:
		# The find shows up: first a white edge under the earth, cleaner the more it is brushed.
		var c := Vector2(80, GROUND + 4 + depth * 16 - 8)
		_icon(c, 18, Color(1, 1, 1, 0.35 + 0.65 * clampf(_brush, 0.0, 1.0)))
		var dirt := 1.0 - clampf(_brush, 0.0, 1.0)
		for i in int(dirt * 14):
			_px(c.x - 8 + (i * 7) % 16, c.y - 6 + (i * 5) % 12, 3, 2, Color(_pal[3]))
		if fmod(_time, 0.6) < 0.3:
			_px(c.x + 7, c.y - 7, 1, 1, Color.WHITE)
	# The shovel stuck in the pile.
	_px(118, GROUND - 26, 2, 22, Color("6b4a2f"))
	_px(115, GROUND - 6, 8, 6, Color("9aa0a6"))
	_px(116, GROUND - 28, 6, 2, Color("6b4a2f"))
	# Progress of the brushing.
	if _dug >= _layers:
		_px(8, 82, 120, 4, Color("1a0f0a"))
		_px(9, 83, 118 * clampf(_brush, 0.0, 1.0), 2, GOLD)


func _draw_catch() -> void:
	if _item == "ether_essence":
		var bright := _sitting()
		var a := 0.35 if not bright else 1.0
		_scene.draw_circle(_pos, 9.0 if bright else 6.0, Color(0.6, 0.8, 1.0, 0.18 * a))
		_scene.draw_circle(_pos, 5.0, Color(0.7, 0.9, 1.0, 0.3 * a))
		_icon(_pos, 14, Color(1, 1, 1, a))
	else:
		var p := _pos
		# Shadow on the ground, stays down while it jumps.
		var ground_y := _from.lerp(_to, clampf(_hop, 0.0, 1.0)).y if _hop >= 0.0 else _pos.y
		_px(p.x - 5, ground_y - 1, 10, 2, Color(0, 0, 0, 0.3))
		var tilt := 0.0
		if _hop < 0.0 and _sit < 0.25 and fmod(_time, 0.1) < 0.05:
			tilt = 1.0  # about to jump
		_icon(p - Vector2(0, 6 + tilt), 16)
	# Misses left.
	var max_miss := int(GameData.GATHER["catch_misses"])
	for i in max_miss:
		_px(4 + i * 5, 4, 3, 3, BAD if i < _misses else Color("6aa84a"))
	if _flash > 0.0:
		_px(0, 0, W, H, Color(1, 0.3, 0.2, _flash * 0.35))


func _draw_result() -> void:
	_px(0, 0, W, H, Color(0, 0, 0, 0.45))
	var c := Vector2(80, 38)
	if _pieces > 0:
		_scene.draw_circle(c, 16, Color(1, 0.85, 0.4, 0.18))
		for i in _pieces:
			_icon(c + Vector2((i - (_pieces - 1) / 2.0) * 22, 0), 20)
	else:
		_icon(c, 20, Color(0.4, 0.35, 0.35, 0.8))
		_scene.draw_line(c - Vector2(9, 9), c + Vector2(9, 9), BAD, 2.0)
		_scene.draw_line(c + Vector2(-9, 9), c + Vector2(9, -9), BAD, 2.0)
