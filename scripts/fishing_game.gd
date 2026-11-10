extends Control
## Fishing mini-game on the lake pier (opened from the location screen, see location_view.gd).
## A cast: click while the power marker runs (farther = bigger fish, GameData.FISHING) -> wait for a bite ->
## click while the float is under water -> reel: hold the mouse button to keep the green zone on the fish
## until the progress bar is full. GameState.fish_cast / fish_roll / land_fish do the game side.
## The scene is drawn in pixels (W x H), seen from above (the lake under the pier), and scaled like the
## brewing / cooking stations.

signal closed

const GameData := preload("res://scripts/game_data.gd")

enum Step { READY, FLY, WAIT, BITE, REEL, RESULT, MISS }

const W := 160
const H := 90
## The reel bar on the right, in scene pixels.
const BAR_X := 140
const BAR_TOP := 12
const BAR_H := 60
const ZONE_RISE := 1.9
const ZONE_FALL := 1.5
const GOLD := Color("f2c14e")
const TEXT := Color("eadbc8")
const MUTED := Color("b8a48c")
## After a catch: seconds the catch is shown before a click (or the timer) starts the next cast.
const CATCH_LOCK := 1.1
const CATCH_SHOW := 2.6
## After a miss: seconds of the "it got away" animation before the next cast.
const MISS_SHOW := 1.4
## Where the catch is held up to look at (scene pixels).
const SHOW_AT := Vector2(80, 36)

var _scene: Control
var _title: Label
var _hint: Label
var _casts: Label
var _close: Button

var _step: Step = Step.READY
var _t: float = 0.0
var _time: float = 0.0
## Power marker 0..1 while READY; the power of the cast after it.
var _power: float = 0.0
var _wait: float = 0.0
var _fish: String = ""
## Reel: fish and zone positions (0 = bottom, 1 = top of the bar), progress 0..1.
var _fish_y: float = 0.5
var _fish_target: float = 0.5
var _fish_timer: float = 0.0
var _zone_y: float = 0.3
var _zone_v: float = 0.0
var _progress: float = 0.0
var _holding: bool = false
var _result: String = ""
var _splash: float = 0.0
## What went wrong on a miss: "early" (pulled too soon), "bait" (missed the bite), "escape" (broke loose while reeling).
var _miss_kind: String = ""
## The catch had no room in the storage and is let go back into the lake.
var _let_go: bool = false
## Little drops and sparkles of the catch / miss animations: {"p", "v", "life", "c", "g", "star"}.
var _bits: Array = []


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
	_casts = Label.new()
	_casts.add_theme_font_size_override("font_size", 16)
	_casts.add_theme_color_override("font_color", MUTED)
	head.add_child(_casts)
	_close = Button.new()
	_close.text = "Змотати вудку"
	_close.focus_mode = Control.FOCUS_NONE
	_close.pressed.connect(close)
	head.add_child(_close)
	_scene = Control.new()
	_scene.custom_minimum_size = Vector2(W, H) * 4.5
	_scene.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_scene.draw.connect(_draw_scene)
	_scene.gui_input.connect(_on_scene_input)
	box.add_child(_scene)
	_hint = Label.new()
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hint.custom_minimum_size = Vector2(W * 4.5, 0)
	_hint.add_theme_font_size_override("font_size", 17)
	_hint.add_theme_color_override("font_color", TEXT)
	box.add_child(_hint)
	set_process(false)


func open() -> void:
	visible = true
	set_process(true)
	_holding = false
	_start_ready()


func close() -> void:
	if _step in [Step.WAIT, Step.BITE, Step.REEL, Step.FLY]:
		_result = ""
	visible = false
	set_process(false)
	closed.emit()


func _start_ready() -> void:
	_t = 0.0
	if GameState.fishing_casts_left() <= 0:
		_fish = ""
		_step = Step.RESULT
		_title.text = "Риболовля"
		_hint.text = (_result + "\n" if _result != "" else "") + "Закиди на сьогодні скінчилися. Приходь завтра."
		_refresh_casts()
		return
	_step = Step.READY
	_title.text = "Риболовля: закидай"
	_hint.text = ((_result + "\n") if _result != "" else "") + "Натисни, коли смужка сили там, де хочеш. Ближче до берега клюють раки, далеко клює щука."
	_refresh_casts()


func _refresh_casts() -> void:
	_casts.text = "Закидів: %d" % GameState.fishing_casts_left()


func _on_scene_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_holding = event.pressed
		if not event.pressed:
			return
		match _step:
			Step.READY:
				if GameState.fish_cast():
					_power = _power_marker()
					_step = Step.FLY
					_t = 0.0
					_result = ""
					Audio.play("cast")
					_title.text = "Риболовля: чекай"
					_hint.text = "Чекай, поки поплавець смикнеться під воду, і тоді одразу натискай!"
					_refresh_casts()
			Step.WAIT, Step.FLY:
				_miss("Зарано! Риба злякалася.", "early")
			Step.BITE:
				_start_reel()
			Step.RESULT:
				# Let the player look at the catch for a moment before the next cast.
				if _t < CATCH_LOCK:
					return
				if GameState.fishing_casts_left() <= 0:
					close()
				else:
					_start_ready()


func _input(event: InputEvent) -> void:
	# Releasing the button outside the scene still counts.
	if visible and event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		_holding = false


func _unhandled_input(event: InputEvent) -> void:
	if visible and event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		close()
		get_viewport().set_input_as_handled()


func _power_marker() -> float:
	return 0.5 - 0.5 * cos(_t * 2.6)


## A failed cast: show what happened for a moment, then get ready for the next one.
func _miss(text: String, kind: String) -> void:
	_result = text
	_miss_kind = kind
	_step = Step.MISS
	_t = 0.0
	_splash = 0.5
	_title.text = "Риболовля"
	_hint.text = text
	Audio.play("fail" if kind == "escape" else "refuse")
	var at := _float_pos(_power)
	if kind == "escape":
		# The fish leaps out of the water and splashes back.
		for i in 6:
			var a := randf() * TAU
			_bits.append({"p": at, "v": Vector2(cos(a), sin(a)) * randf_range(12, 24), "life": 0.5, "c": Color(0.9, 0.97, 1.0, 0.8), "drag": true, "big": true})
	_refresh_casts()


func _start_reel() -> void:
	_fish = GameState.fish_roll(_power)
	_step = Step.REEL
	_t = 0.0
	_progress = float(GameData.FISHING["start"])
	_fish_y = 0.5
	_fish_target = randf()
	_zone_y = 0.35
	_zone_v = 0.0
	_splash = 0.6
	Audio.play("splash")
	_title.text = "Риболовля: тягни!"
	_hint.text = "Тримай кнопку миші, щоб підняти зелену рамку, і відпусти, щоб опустити. Тримай рибу в рамці!"


func _process(delta: float) -> void:
	_time += delta
	_t += delta
	_splash = maxf(0.0, _splash - delta)
	match _step:
		Step.FLY:
			if _t >= 0.6:
				_step = Step.WAIT
				_t = 0.0
				_splash = 0.4
				var w: Array = GameData.FISHING["wait"]
				_wait = randf_range(float(w[0]), float(w[1]))
		Step.WAIT:
			if _t >= _wait:
				_step = Step.BITE
				_t = 0.0
				_splash = 0.3
				Audio.play("bite")
				_hint.text = "Клює! Тисни!"
		Step.BITE:
			if _t >= float(GameData.FISHING["bite_window"]):
				_miss("Риба з'їла наживку й пішла.", "bait")
		Step.REEL:
			_process_reel(delta)
		Step.MISS:
			if _miss_kind == "bait" and randf() < delta * 10:
				var at := _float_pos(_power)
				_bits.append({"p": at + Vector2(randf_range(-2, 2), 0), "v": Vector2(randf_range(-2, 2), randf_range(-2, 2)), "life": 0.4, "c": Color(0.9, 0.97, 1.0, 0.7), "g": 0.0})
			if _t >= MISS_SHOW:
				_start_ready()
		Step.RESULT:
			_process_catch(delta)
	for b in _bits:
		var v: Vector2 = b["v"]
		v.y += float(b.get("g", 0.0)) * delta
		if b.has("drag"):
			v *= maxf(0.0, 1.0 - 4.0 * delta)
		b["v"] = v
		b["p"] = Vector2(b["p"]) + v * delta
		b["life"] = float(b["life"]) - delta
	_bits = _bits.filter(func(b): return b["life"] > 0.0)
	_scene.queue_redraw()


func _process_reel(delta: float) -> void:
	var f: Dictionary = GameData.FISHING["fish"][_fish]
	var speed := float(f["speed"])
	# The fish darts to a new depth now and then.
	_fish_timer -= delta
	if _fish_timer <= 0.0:
		_fish_target = clampf(_fish_y + randf_range(-0.6, 0.6), 0.04, 0.96)
		_fish_timer = randf_range(0.35, 1.1) / speed
	_fish_y = move_toward(_fish_y, _fish_target, delta * 0.55 * speed * (1.0 + 0.5 * sin(_time * 7.0)))
	# The zone: rises while the button is held, falls when it is not.
	_zone_v += (ZONE_RISE if _holding else -ZONE_FALL) * delta
	_zone_v = clampf(_zone_v, -0.9, 0.9)
	_zone_y += _zone_v * delta
	var zone_h := float(f["zone"]) / BAR_H
	if _zone_y < 0.0:
		_zone_y = 0.0
		_zone_v = maxf(0.0, _zone_v) * 0.3
	elif _zone_y > 1.0 - zone_h:
		_zone_y = 1.0 - zone_h
		_zone_v = minf(0.0, _zone_v) * 0.3
	var inside := _fish_y >= _zone_y and _fish_y <= _zone_y + zone_h
	_progress += (float(GameData.FISHING["gain"]) if inside else -float(GameData.FISHING["loss"])) * delta
	if _progress >= 1.0:
		_result = GameState.land_fish(_fish)
		_let_go = _result.contains("відпустити")
		_step = Step.RESULT
		_t = 0.0
		_splash = 0.6
		_title.text = "Риболовля"
		_hint.text = _result + ("\nНатисни, щоб закинути ще." if GameState.fishing_casts_left() > 0 else "\nЗакиди на сьогодні скінчилися.")
		_refresh_casts()
		var at := _float_pos(_power)
		for i in 8:
			var a := randf() * TAU
			_bits.append({"p": at, "v": Vector2(cos(a), sin(a)) * randf_range(14, 28), "life": 0.5, "c": Color(0.9, 0.97, 1.0, 0.85), "drag": true, "big": true})
		get_tree().create_timer(CATCH_SHOW).timeout.connect(_after_result)
	elif _progress <= 0.0:
		_miss("Зірвалася! Волосінь ослабла, і риба пішла в глибину.", "escape")


## The catch in the air: drops fall off it, sparkles when it is held up.
func _process_catch(delta: float) -> void:
	var at := _catch_pos()
	if _t < 1.6 and randf() < delta * 8:
		_bits.append({"p": at + Vector2(randf_range(-5, 5), 4), "v": Vector2(randf_range(-3, 3), randf_range(0, 6)), "life": 0.5, "c": Color(0.8, 0.92, 1.0, 0.8), "g": 40.0})
	if _t > 0.55 and _t - delta <= 0.55 and not _let_go:
		for k in 10:
			var a := k * TAU / 10.0
			_bits.append({"p": at, "v": Vector2(cos(a), sin(a)) * randf_range(16, 28), "life": 0.6, "c": GOLD.lightened(randf_range(0.0, 0.4)), "g": 0.0, "star": k % 2 == 0, "drag": true})


## Where the catch is drawn: flies up from the float, hangs in the middle (let go: drops back into the lake).
func _catch_pos() -> Vector2:
	var from := _float_pos(_power)
	if _t < 0.55:
		var k := _t / 0.55
		k = 1.0 - (1.0 - k) * (1.0 - k)
		return from.lerp(SHOW_AT, k) - Vector2(0, sin(k * PI) * 6)
	if _let_go and _t > 1.4:
		var k := minf(1.0, (_t - 1.4) / 0.5)
		return SHOW_AT.lerp(from, k * k)
	return SHOW_AT + Vector2(0, roundf(sin(_t * 3.0) * 1.5))


## After a catch the next cast is ready by itself (the text stays a bit).
func _after_result() -> void:
	if visible and _step == Step.RESULT and GameState.fishing_casts_left() > 0:
		_start_ready()


# ---------- Drawing (scene pixels) ----------

func _scale() -> float:
	return floorf(minf(_scene.size.x / W, _scene.size.y / H) * 2.0) / 2.0


func _offset() -> Vector2:
	return (_scene.size - Vector2(W, H) * _scale()) / 2.0


func _px(x: float, y: float, w: float, h: float, c: Color) -> void:
	_scene.draw_rect(Rect2(floorf(x), floorf(y), w, h), c)


## Where the float is on the water for a cast of power p.
func _float_pos(p: float) -> Vector2:
	return Vector2(52 + p * 76, 66 - p * 34)


func _draw_scene() -> void:
	_scene.draw_set_transform(_offset(), 0.0, Vector2.ONE * _scale())
	_draw_lake()
	# The angler at the end of the pier and the rod (seen from above it bends sideways when a fish pulls).
	var hands := Vector2(27, 60)
	var tip := Vector2(46, 42)
	var bend := 0.0
	if _step == Step.REEL:
		bend = 3.0 + 2.0 * sin(_time * 12.0)
	elif _step == Step.BITE:
		bend = 2.0
	var side := (tip - hands).orthogonal().normalized()
	for i in 21:
		var t := i / 20.0
		var p := hands.lerp(tip, t) + side * bend * t * t
		_px(p.x, p.y, 1 if t > 0.4 else 2, 1 if t > 0.4 else 2, Color("5a3a20") if t > 0.15 else Color("2a1a10"))
	tip += side * bend
	_draw_angler(hands)
	# Power bar while choosing the cast.
	if _step == Step.READY:
		_px(48, 80, 84, 6, Color("1a0f0a"))
		for i in 82:
			_px(49 + i, 81, 1, 4, Color("6aa84a").lerp(Color("e0603a"), i / 82.0))
		var m := _power_marker()
		_px(48 + m * 82, 78, 2, 10, Color.WHITE)
		var fp := _float_pos(m)
		_ring(fp, 1.5 + fmod(_time * 3.0, 1.0) * 2.0, Color(1, 1, 1, 0.5 * (1.0 - fmod(_time * 3.0, 1.0))))
		_px(fp.x, fp.y, 1, 1, Color(1, 1, 1, 0.5 + 0.5 * sin(_time * 8.0)))
		# A dotted guide where the float would land.
		for i in 6:
			var g := tip.lerp(fp, i / 6.0)
			_px(g.x, g.y, 1, 1, Color(1, 1, 1, 0.25))
		_scene.draw_set_transform(Vector2.ZERO)
		return
	if _step == Step.MISS:
		_draw_miss(tip)
		_draw_bits()
		_scene.draw_set_transform(Vector2.ZERO)
		return
	if _step == Step.RESULT and _t < 2.4 and _fish != "":
		_draw_catch(tip)
		_draw_bits()
		_scene.draw_set_transform(Vector2.ZERO)
		return
	# Line and float. While it flies, the float rises towards the camera (bigger), its shadow on the water.
	var fpos := _float_pos(_power)
	var lift := 0.0
	if _step == Step.FLY:
		var k := clampf(_t / 0.6, 0.0, 1.0)
		var ground := tip.lerp(fpos, k)
		lift = sin(k * PI)
		_px(ground.x + 1 + lift * 3, ground.y + 1 + lift * 5, 2, 1, Color(0, 0, 0, 0.25))
		fpos = ground - Vector2(0, lift * 4)
	var under := _step == Step.BITE or _step == Step.REEL
	var bob := 0.0
	if _step == Step.WAIT:
		bob = roundf(sin(_time * 3.0) * 0.6)
		if _wait - _t < 0.8 and fmod(_time, 0.3) < 0.1:
			bob = -1.0  # a nibble before the bite
	_draw_line(tip, fpos, 0.0 if under else (5.0 if _step != Step.FLY else 2.0))
	if under:
		# Pulled under: only a dark dot and the line cutting the water.
		_px(fpos.x, fpos.y, 1, 1, Color("6a1a14"))
		if _step == Step.REEL:
			var wake := Vector2(sin(_time * 9.0), cos(_time * 7.0)) * 2.0
			_px(fpos.x + wake.x, fpos.y + wake.y, 2, 1, Color(1, 1, 1, 0.5))
	elif _step == Step.FLY and lift > 0.3:
		_px(fpos.x - 1, fpos.y - 1, 3, 3, Color("e83a2a"))
		_px(fpos.x, fpos.y, 1, 1, Color.WHITE)
	else:
		# The float from above: a red cap with a white tip, a ring of water round it; it dips on a nibble.
		if bob < 0.0:
			_px(fpos.x, fpos.y, 1, 1, Color("e83a2a"))
			_ring(fpos, 2.5, Color(1, 1, 1, 0.5))
		else:
			_ring(fpos, 2.0 + bob * 0.5, Color(1, 1, 1, 0.25))
			_px(fpos.x - 1, fpos.y - 1, 2, 2, Color("e83a2a"))
			_px(fpos.x - 1, fpos.y - 1, 1, 1, Color.WHITE)
	if _splash > 0.0 or _step == Step.BITE:
		var r := 2.0 + (1.0 - _splash) * 5.0 if _splash > 0.0 else 2.0 + fmod(_time * 6.0, 3.0)
		_ring(fpos, r, Color(1, 1, 1, 0.6))
	if _step == Step.BITE:
		_px(fpos.x - 1, fpos.y - 12, 2, 5, GOLD)
		_px(fpos.x - 1, fpos.y - 6, 2, 2, GOLD)
	if _step == Step.REEL:
		_draw_reel()
	_scene.draw_set_transform(Vector2.ZERO)


## The lake seen from above: the far bank with treetops at the top, deeper water further out, the sandy bank
## and the pier at the bottom left, lily pads, a few fish shadows gliding under the surface.
func _draw_lake() -> void:
	for y in range(0, H, 2):
		for x in range(0, W, 4):
			var near := clampf(1.0 - Vector2(x, y).distance_to(Vector2(0, H)) / 150.0, 0.0, 1.0)
			var top := clampf(1.0 - y / 18.0, 0.0, 1.0)
			var col := Color("1e5070").lerp(Color("4a90b0"), near * 0.9).lerp(Color("3a7a8a"), top * 0.6)
			_px(x, y, 4, 2, col)
	# Fish shadows.
	for i in 3:
		var a := _time * (0.25 + i * 0.07) + i * 2.1
		var c := Vector2(95 + i * 14 + cos(a) * (22 - i * 4), 40 + sin(a * 1.3) * (12 + i * 3))
		var dir := Vector2(-sin(a), cos(a * 1.3) * 1.3).normalized()
		for j in 5:
			var p := c - dir * j
			_px(p.x, p.y, 2 if j < 3 else 1, 2 if j < 3 else 1, Color(0.05, 0.12, 0.18, 0.35))
	# Wave crests: drift, swell and fade.
	for i in 40:
		var y := 12 + (i * 37) % 70
		var x := fmod(i * 53.0 + _time * (3.0 + i % 3) * (1.0 if i % 2 else -0.7) + 400.0, W + 20.0) - 10.0
		var life := 0.5 + 0.5 * sin(_time * (0.9 + (i % 4) * 0.2) + i * 1.7)
		if life < 0.2:
			continue
		var w := roundf((2.0 + (i % 3) * 1.5) * life)
		_px(x, y, w, 1, Color(0.85, 0.95, 1.0, 0.15 + 0.3 * life))
	# The far bank: grass, reeds and round treetops.
	for x in range(0, W, 2):
		var h := 5 + int(absf(sin(x * 0.21)) * 3 + absf(sin(x * 0.07)) * 2)
		_px(x, 0, 2, h, Color("4a6a32"))
		_px(x, h, 2, 1, Color("6a5a3a"))
		if (x * 7) % 5 == 0:
			_px(x, h + 1, 1, 2, Color("6a8a3a"))
	for i in 9:
		var c := Vector2(8 + i * 18 + (i * 7) % 6, 1 + (i * 3) % 3)
		var r := 5.0 + (i * 5) % 3
		_disc(c + Vector2(1, 2), r, Color(0.05, 0.1, 0.05, 0.4))
		_disc(c, r, Color("2e5a30"))
		_disc(c + Vector2(-1, -1), r - 2, Color("3e7038"))
		_px(c.x - 2, c.y - 2, 2, 1, Color("5a8a48"))
	# Lily pads (one with a flower) bobbing gently.
	for i in 4:
		var c := Vector2([108, 116, 70, 150][i], [62, 70, 20, 52][i]) + Vector2(0, roundf(sin(_time * 1.2 + i)))
		_disc(c, 3, Color("3a7a3a"))
		_px(c.x, c.y - 3, 1, 3, Color("2e6a8a"))
		_px(c.x - 1, c.y - 1, 1, 1, Color("5a9a4a"))
		if i == 1:
			_px(c.x + 1, c.y, 2, 2, Color("f0c0d0"))
			_px(c.x + 1, c.y, 1, 1, Color("ffe0a0"))
	# Sandy bank in the bottom left with the water lapping at it.
	for y in range(58, H):
		var w := 18.0 + (y - 58) * 1.4 + sin(y * 0.8) * 1.0
		_px(0, y, w, 1, Color("b89a6a") if y % 3 else Color("a88a5a"))
		_px(w, y, 1, 1, Color("8a7a5a"))
		var k := fmod(_time * 0.5 + y * 0.13, 1.0)
		_px(w + 1 + k * 3, y, 2, 1, Color(0.9, 0.97, 1.0, 0.45 * (1.0 - k)))
	# The pier: boards across, two rows of posts.
	_px(19, 52, 15, H - 52, Color(0, 0, 0, 0.3))
	for y in range(50, H):
		_px(17, y, 14, 1, Color("8a6a44") if (y / 3) % 2 else Color("7a5c3a"))
		if y % 3 == 0:
			_px(17, y, 14, 1, Color("5a4228"))
	for p in [Vector2(16, 50), Vector2(30, 50), Vector2(16, 70), Vector2(30, 70)]:
		_disc(p, 1.5, Color("3a2614"))


## The angler seen from above: a wide straw hat, shoulders, the hands on the rod.
func _draw_angler(hands: Vector2) -> void:
	var c := Vector2(23, 66)
	_disc(c + Vector2(2, 2), 5, Color(0, 0, 0, 0.3))
	_px(c.x - 5, c.y - 1, 11, 5, Color("4a5a7a"))
	_px(c.x - 5, c.y - 1, 11, 1, Color("6a7a9a"))
	_line(c + Vector2(3, -1), hands, Color("4a5a7a"))
	_disc(hands, 1, Color("e0b090"))
	_disc(c, 4, Color("c8a050"))
	_disc(c + Vector2(-1, -1), 2, Color("e8c870"))
	_px(c.x - 4, c.y, 9, 1, Color("8a3a2a"))


func _disc(c: Vector2, r: float, col: Color) -> void:
	for y in range(-int(r), int(r) + 1):
		var hw := floorf(sqrt(maxf(0.0, r * r - y * y)) + 0.3)
		_px(c.x - hw, c.y + y, hw * 2 + 1, 1, col)


func _line(a: Vector2, b: Vector2, col: Color) -> void:
	var n := int(maxf(absf(b.x - a.x), absf(b.y - a.y)))
	for i in n + 1:
		var p := a.lerp(b, float(i) / maxf(1.0, n))
		_px(p.x, p.y, 1, 1, col)


## Fishing line from the rod tip to `to`; slack line curves sideways on the water.
func _draw_line(from: Vector2, to: Vector2, sag: float) -> void:
	var side := (to - from).orthogonal().normalized()
	for i in 24:
		var t := i / 24.0
		var p := from.lerp(to, t) + side * sin(t * PI) * sag
		_px(p.x, p.y, 1, 1, Color(0.95, 0.95, 0.9, 0.8))


## Circle outline on the water.
func _ring(c: Vector2, r: float, col: Color) -> void:
	var n := maxi(10, int(r * 6))
	for i in n:
		var a := i * TAU / n
		_px(roundf(c.x + cos(a) * r), roundf(c.y + sin(a) * r), 1, 1, col)


func _draw_bits() -> void:
	for b in _bits:
		var c: Color = b["c"]
		var p: Vector2 = b["p"]
		if b.get("star", false) and float(b["life"]) > 0.2:
			_px(p.x - 1, p.y, 3, 1, Color(c, 0.6))
			_px(p.x, p.y - 1, 1, 3, Color(c, 0.6))
		var s := 2.0 if b.get("big", false) and float(b["life"]) > 0.3 else 1.0
		_px(p.x, p.y, s, s, c)


## Rings spreading on the water from a point.
func _rings(at: Vector2, t: float, alpha: float) -> void:
	for j in 2:
		var k := fmod(t * 1.3 + j * 0.5, 1.0)
		_ring(at, 1.0 + k * 7.0, Color(1, 1, 1, alpha * (1.0 - k)))


## A fish seen from above at `p`, heading `dir`, `s` = size (grows when it leaps up towards the camera).
func _draw_fish_top(p: Vector2, dir: Vector2, s: float) -> void:
	var col := _fish_color()
	var n := int(4 * s)
	for j in n:
		var q := p - dir * j
		var w := 2.0 if j < n * 0.7 else 1.0
		_px(q.x, q.y, w * s * 0.5 + 0.5, w * s * 0.5 + 0.5, col if j > 0 else col.lightened(0.2))
	var tail := p - dir * (n + 1)
	var flick := dir.orthogonal() * roundf(sin(_time * 30)) * s
	_px(tail.x + flick.x - 1, tail.y + flick.y, 3, 1, col.darkened(0.2))
	_px(p.x, p.y, 1, 1, Color.BLACK)


## The cast went wrong: the line goes slack and is reeled in, rings on the water, the fish jumps off / bubbles.
func _draw_miss(tip: Vector2) -> void:
	var spot := _float_pos(_power)
	var k := clampf((_t - 0.5) / 0.8, 0.0, 1.0)
	var fpos := spot.lerp(tip + Vector2(2, 4), k * k)
	_draw_line(tip, fpos, 7.0 * (1.0 - k))
	_px(fpos.x - 1, fpos.y - 1, 2, 2, Color("e83a2a"))
	_px(fpos.x - 1, fpos.y - 1, 1, 1, Color.WHITE)
	_rings(spot, _t, 0.6 * (1.0 - minf(1.0, _t / MISS_SHOW)))
	if _miss_kind == "escape" and _t < 0.7:
		# The fish leaps away: up towards the camera (bigger), its shadow on the water, then back in.
		var j := _t / 0.7
		var ground := spot + Vector2(j * 16, -j * 6)
		var lift := sin(j * PI)
		_px(ground.x - 2, ground.y + 1, 5, 2, Color(0, 0, 0, 0.3))
		_draw_fish_top(ground - Vector2(0, lift * 6), Vector2(16, -6).normalized(), 1.0 + lift)


func _fish_color() -> Color:
	match _fish:
		"pike":
			return Color("8ab060")
		"crayfish":
			return Color("e06a40")
		"purse":
			return Color("a07040")
	return Color("e0c060")


## The catch is pulled out of the water and up towards the camera: it grows, its shadow stays on the water,
## the line runs to it, it wriggles, then sparkles.
func _draw_catch(tip: Vector2) -> void:
	var at := _catch_pos()
	var hold := _t >= 0.55 and not (_let_go and _t > 1.4)
	var from := _float_pos(_power)
	var k := clampf(_t / 0.55, 0.0, 1.0)
	if _let_go and _t > 1.4:
		k = 1.0 - minf(1.0, (_t - 1.4) / 0.5)
	var shadow := from.lerp(SHOW_AT, k) + Vector2(4, 10) * k
	for y in range(-2, 3):
		var hw := floorf(sqrt(maxf(0.0, 4.0 - y * y)) * (2.0 + 3.0 * k))
		_px(shadow.x - hw, shadow.y + y, hw * 2 + 1, 1, Color(0, 0, 0, 0.25))
	_draw_line(tip, at + Vector2(0, -6), 0.0)
	_rings(from, _t, 0.5 * maxf(0.0, 1.0 - _t))
	if hold and not _let_go:
		# Soft glow behind the catch.
		for r in [12, 9]:
			_disc(at, float(r), Color(GOLD, 0.06 + 0.03 * sin(_time * 4)))
	var sz := 16.0 if hold else 8.0 + 8.0 * k
	# Wriggle: squash and stretch a bit.
	var wig := sin(_time * (14.0 if _t < 1.2 else 5.0)) * (1.5 if _t < 1.2 else 0.5)
	var rect := Rect2(at.x - (sz + wig) / 2.0, at.y - (sz - wig) / 2.0, sz + wig, sz - wig)
	if _fish == "purse":
		_draw_purse(rect)
	elif GameData.ITEMS.has(_fish):
		_scene.draw_texture_rect(GameData.icon_texture(_fish), rect, false)


## A wet leather purse with a coin peeking out.
func _draw_purse(r: Rect2) -> void:
	var c := r.get_center()
	_px(c.x - 5, c.y - 3, 11, 8, Color("1a0f0a"))
	_px(c.x - 4, c.y - 2, 9, 6, Color("a07040"))
	_px(c.x - 4, c.y - 2, 3, 2, Color("c49a64"))
	_px(c.x - 2, c.y - 5, 5, 2, Color("6a4426"))
	_px(c.x - 1, c.y - 6, 3, 1, Color("1a0f0a"))
	_px(c.x + 2, c.y - 7 + roundf(sin(_time * 5)), 3, 3, GOLD)
	_px(c.x + 2, c.y - 7 + roundf(sin(_time * 5)), 1, 1, Color("fff0a0"))


func _draw_reel() -> void:
	var f: Dictionary = GameData.FISHING["fish"][_fish]
	_px(BAR_X - 2, BAR_TOP - 2, 12, BAR_H + 4, Color("1a0f0a"))
	_px(BAR_X, BAR_TOP, 8, BAR_H, Color("2e5a7a"))
	var zh := float(f["zone"])
	var zy := BAR_TOP + BAR_H - (_zone_y * BAR_H) - zh
	var inside := _fish_y >= _zone_y and _fish_y <= _zone_y + zh / BAR_H
	_px(BAR_X, zy, 8, zh, Color(0.4, 0.9, 0.4, 0.55 if inside else 0.35))
	_px(BAR_X, zy, 8, 1, Color("8af08a"))
	_px(BAR_X, zy + zh - 1, 8, 1, Color("8af08a"))
	# The fish: a little silhouette.
	var fy := BAR_TOP + BAR_H - _fish_y * BAR_H
	var col := Color("e0c060") if _fish != "pike" else Color("8ab060")
	if _fish == "crayfish":
		col = Color("e06a40")
	elif _fish == "purse":
		col = Color("a07040")
	_px(BAR_X + 2, fy - 1, 4, 3, col)
	_px(BAR_X + 6, fy - 2, 1, 5, col)
	_px(BAR_X + 2, fy - 1, 1, 1, Color.BLACK)
	# Progress.
	_px(BAR_X + 11, BAR_TOP - 2, 5, BAR_H + 4, Color("1a0f0a"))
	var ph := clampf(_progress, 0.0, 1.0) * BAR_H
	_px(BAR_X + 12, BAR_TOP + BAR_H - ph, 3, ph, GOLD.lerp(Color("8af08a"), _progress))
