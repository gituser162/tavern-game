extends Control
## Interactive brewing in four short steps, drawn in the 320x180 pixel style of the tavern:
## 1) grind the herbs in the mortar (hold the mouse button and rub),
## 2) stir them with water in the cauldron (hold and circle the spoon three times),
## 3) heat it on the alchemy station (hold to fan the fire, keep the needle in the green zone),
## 4) let it cool (waits by itself; clicks blow on it to speed up).
## Nothing is spent here: when the potion is poured into the bottle the station emits `finished`
## and main.gd calls GameState.brew(). There is no way to fail: overheating only boils over and cools the pot down.

signal finished
signal step_changed(step: int)

enum Step { GRIND, STIR, HEAT, COOL, POUR, DONE }

const W := 160
const H := 84
const TITLES := ["Розітри траву", "Розмішай з рідиною", "Розігрій на станції", "Дай схолонути"]
const HINTS := [
	"Затисни ліву кнопку миші в ступці й потри товкачиком, поки трава не стане порошком.",
	"Затисни кнопку й покрути ложкою в казанку по колу: три оберти.",
	"Тримай кнопку миші, щоб роздмухати вогонь, і тримай стрілку в зеленій зоні. Перегрієш, і зілля википить через край: доведеться почекати, поки охолоне.",
	"Зілля холоне саме. Клацай по ньому, щоб подути й прискорити.",
	"Розливаю в пляшечку…",
	"Готово!",
]

## How much rubbing (logical pixels of mouse travel) turns the herbs into powder.
const GRIND_DISTANCE := 170.0
const STIR_TURNS := 3.0
const HEAT_RISE := 0.42
const HEAT_FALL := 0.22
const HEAT_ZONE := Vector2(0.58, 0.84)
const HEAT_SECONDS := 2.2
const COOL_SECONDS := 4.0
const BLOW := 0.1
const POUR_SECONDS := 1.0

# Palette taken from the tavern background.
const C_WALL := Color("160c05")
const C_WALL2 := Color("1b1008")
const C_SEAM := Color("0b0503")
const C_TABLE_TOP := Color("6e4e30")
const C_TABLE := Color("3d2614")
const C_TABLE_DARK := Color("25150b")
const C_OUT := Color("1a0f0a")
const C_STONE1 := Color("b4a894")
const C_STONE2 := Color("968a78")
const C_STONE3 := Color("7a6f60")
const C_STONE4 := Color("5e554a")
const C_STONE5 := Color("443c34")
const C_BRICK := Color("3b3125")
const C_BRICK2 := Color("2d251c")
const C_IRON := Color("2a221c")
const C_IRON2 := Color("443c34")
const C_IRON3 := Color("5e554a")
const C_WATER := Color("4a7ab0")
const C_GLASS := Color("8fb8c8")
const C_FIRE := [Color("fff0a0"), Color("f2c14e"), Color("ff8a2a"), Color("c83a1a")]
const C_GREEN := Color("7ab04e")
const C_RED := Color("c83a1a")

const MORTAR := Vector2(34, 58)     # bottom middle of the mortar
const CAULDRON := Vector2(86, 42)   # centre of the cauldron body
const SURFACE_Y := 33
const THERMO := Rect2(110, 18, 5, 38)
const BOTTLE := Vector2(136, 58)    # bottom middle of the bottle

var potion_id := ""
var step: int = Step.GRIND
var potion_color := Color("9a4ac8")
var herb_color := Color("4f8a3a")

var _grind := 0.0
var _stir := 0.0
var _stir_angle := 0.0
var _heat := 0.0
var _temp := 0.0
var _cool := 0.0
var _pour := 0.0
var _boil := 0.0
var _pressed := false
var _mouse := Vector2(-100, -100)
var _pestle := Vector2.ZERO
var _chunks: Array = []
var _particles: Array = []
var _t := 0.0
var _sound_mark := 0
var _transfer := 0.0


func _ready() -> void:
	custom_minimum_size = Vector2(W, H) * 4
	mouse_filter = Control.MOUSE_FILTER_STOP
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	set_process(false)


## Starts a new brew of this recipe. Colours come from GameData.RECIPES ("color", "herb").
func start(id: String, recipe: Dictionary) -> void:
	potion_id = id
	potion_color = Color(recipe.get("color", "9a4ac8"))
	herb_color = Color(recipe.get("herb", "4f8a3a"))
	step = Step.GRIND
	_grind = 0.0
	_stir = 0.0
	_stir_angle = -PI / 2
	_heat = 0.0
	_temp = 0.0
	_cool = 0.0
	_pour = 0.0
	_boil = 0.0
	_transfer = 0.0
	_pressed = false
	_sound_mark = 0
	_particles.clear()
	_pestle = MORTAR + Vector2(0, -12)
	_chunks.clear()
	var rng := RandomNumberGenerator.new()
	for i in 14:
		var x := rng.randi_range(-9, 8)
		var y := rng.randi_range(-1, 3) - absi(x) / 5
		var shade := rng.randf_range(-0.25, 0.2)
		_chunks.append({"p": Vector2(x, y), "w": rng.randi_range(2, 3), "c": herb_color.lightened(shade) if shade > 0 else herb_color.darkened(-shade)})
	set_process(true)
	step_changed.emit(step)
	queue_redraw()


func stop() -> void:
	set_process(false)
	_pressed = false


## 0..1 progress of the current step (for the bar under the scene).
func progress() -> float:
	match step:
		Step.GRIND:
			return _grind
		Step.STIR:
			return _stir
		Step.HEAT:
			return _heat
		Step.COOL:
			return _cool
	return 1.0


# ---------- Input ----------

func _scale() -> float:
	return maxf(1.0, floorf(minf(size.x / W, size.y / H)))


func _offset() -> Vector2:
	return ((size - Vector2(W, H) * _scale()) / 2).floor()


func _to_logical(p: Vector2) -> Vector2:
	return (p - _offset()) / _scale()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_pressed = event.pressed
		_mouse = _to_logical(event.position)
		if event.pressed:
			_on_click()
		accept_event()
	elif event is InputEventMouseMotion:
		var p := _to_logical(event.position)
		if _pressed:
			_on_drag(_mouse, p)
		_mouse = p


func _on_click() -> void:
	match step:
		Step.GRIND:
			if _in_mortar(_mouse):
				_pestle = _clamp_to_mortar(_mouse)
				_add_grind(6.0)
		Step.COOL:
			_cool = minf(1.0, _cool + BLOW)
			Audio.play("page")
			for i in 4:
				_particles.append({"p": Vector2(CAULDRON.x - 22, SURFACE_Y - 6 + i), "v": Vector2(randf_range(28, 40), randf_range(-4, 4)), "life": 0.5, "c": Color(0.9, 0.9, 1.0, 0.6)})
			if _cool >= 1.0:
				_next()


func _on_drag(from: Vector2, to: Vector2) -> void:
	match step:
		Step.GRIND:
			if _in_mortar(to):
				var tip := _clamp_to_mortar(to)
				_add_grind(tip.distance_to(_pestle))
				_pestle = tip
		Step.STIR:
			if to.distance_to(CAULDRON) < 26 and from.distance_to(CAULDRON) < 26:
				var a := (to - Vector2(CAULDRON.x, SURFACE_Y)).angle()
				var delta := wrapf(a - _stir_angle, -PI, PI)
				_stir_angle = a
				_stir = minf(1.0, _stir + absf(delta) / (TAU * STIR_TURNS))
				var mark := int(_stir * STIR_TURNS * 2)
				if mark > _sound_mark:
					_sound_mark = mark
					Audio.play("gather")
				if _stir >= 1.0:
					_next()


func _in_mortar(p: Vector2) -> bool:
	return absf(p.x - MORTAR.x) < 20 and p.y > MORTAR.y - 30 and p.y < MORTAR.y + 4


func _clamp_to_mortar(p: Vector2) -> Vector2:
	return Vector2(clampf(p.x, MORTAR.x - 9, MORTAR.x + 9), clampf(p.y, MORTAR.y - 15, MORTAR.y - 11))


func _add_grind(amount: float) -> void:
	_grind = minf(1.0, _grind + amount / GRIND_DISTANCE)
	if randf() < 0.25:
		_particles.append({"p": _pestle + Vector2(randf_range(-3, 3), 0), "v": Vector2(randf_range(-12, 12), randf_range(-22, -10)), "life": 0.4, "c": herb_color.lightened(0.3), "g": 60.0})
	var mark := int(_grind * 5)
	if mark > _sound_mark:
		_sound_mark = mark
		Audio.play("gather")
	if _grind >= 1.0:
		_next()


func _next() -> void:
	_sound_mark = 0
	_pressed = false
	match step:
		Step.GRIND:
			_transfer = 1.0
			Audio.play("magic")
		Step.STIR, Step.HEAT:
			Audio.play("brew")
		Step.COOL:
			Audio.play("buy")
	step += 1
	step_changed.emit(step)


# ---------- Simulation ----------

func _process(delta: float) -> void:
	_t += delta
	if _transfer > 0:
		_transfer = maxf(0.0, _transfer - delta * 1.6)
	if _boil > 0:
		_boil = maxf(0.0, _boil - delta)
	match step:
		Step.HEAT:
			if _boil > 0:
				_temp = maxf(0.3, _temp - HEAT_FALL * 3 * delta)
			elif _pressed:
				_temp += HEAT_RISE * delta
			else:
				_temp = maxf(0.0, _temp - HEAT_FALL * delta)
			if _temp >= 1.0:
				_temp = 1.0
				_boil = 1.0
				Audio.play("error")
				for i in 10:
					_particles.append({"p": Vector2(CAULDRON.x + randf_range(-10, 10), SURFACE_Y - 1), "v": Vector2(randf_range(-20, 20), randf_range(-35, -15)), "life": 0.7, "c": potion_color.lightened(0.2), "g": 80.0})
			elif _temp >= HEAT_ZONE.x and _temp <= HEAT_ZONE.y and _boil <= 0:
				_heat = minf(1.0, _heat + delta / HEAT_SECONDS)
				if _heat >= 1.0:
					_next()
		Step.COOL:
			_temp = maxf(0.0, _temp - delta * 0.2)
			_cool = minf(1.0, _cool + delta / COOL_SECONDS)
			if _cool >= 1.0:
				_next()
		Step.POUR:
			_pour = minf(1.0, _pour + delta / POUR_SECONDS)
			if _pour >= 1.0:
				step = Step.DONE
				set_process(false)
				step_changed.emit(step)
				finished.emit()
	# Steam over a hot pot, bubbles while heating.
	var hot := _temp if step >= Step.HEAT else 0.0
	if step == Step.COOL:
		hot = 0.25 + 0.75 * (1.0 - _cool)
	if hot > 0.2 and randf() < hot * delta * 14:
		_particles.append({"p": Vector2(CAULDRON.x + randf_range(-8, 8), SURFACE_Y - 2), "v": Vector2(randf_range(-3, 3), randf_range(-14, -8)), "life": randf_range(0.8, 1.4), "c": Color(0.85, 0.82, 0.78, 0.45), "steam": true})
	for p in _particles:
		var v: Vector2 = p["v"]
		v.y += float(p.get("g", 0.0)) * delta
		p["v"] = v
		p["life"] = float(p["life"]) - delta
		p["p"] = Vector2(p["p"]) + v * delta
	_particles = _particles.filter(func(p): return p["life"] > 0)
	queue_redraw()


func liquid_color() -> Color:
	match step:
		Step.GRIND:
			return C_WATER
		Step.STIR:
			return C_WATER.lerp(potion_color.darkened(0.35), _stir)
		Step.HEAT:
			return potion_color.darkened(0.35).lerp(potion_color.darkened(0.1), _heat)
		Step.COOL:
			return potion_color.darkened(0.1).lerp(potion_color.lightened(0.08), _cool)
	return potion_color.lightened(0.08)


# ---------- Drawing (logical 160x84 pixels) ----------

func _draw() -> void:
	draw_set_transform(_offset(), 0.0, Vector2.ONE * _scale())
	_draw_room()
	_draw_station()
	_draw_mortar()
	_draw_thermo()
	_draw_bottle()
	for p in _particles:
		var c: Color = p["c"]
		if p.has("steam"):
			c.a *= clampf(p["life"], 0.0, 1.0)
		_px(p["p"].x, p["p"].y, 1, 1, c)
	_draw_transfer()
	_draw_pointer()
	_draw_bar()
	draw_set_transform(Vector2.ZERO)


func _px(x: float, y: float, w: float, h: float, c: Color) -> void:
	draw_rect(Rect2(floorf(x), floorf(y), w, h), c)


## Filled ellipse made of whole-pixel rows. `half` = 0 whole, 1 top half only, 2 bottom half only.
func _ellipse(cx: float, cy: float, rx: float, ry: float, c: Color, half: int = 0) -> void:
	var y0 := -int(ry) if half != 2 else 0
	var y1 := int(ry) if half != 1 else 0
	for y in range(y0, y1 + 1):
		var t := float(y) / maxf(ry, 0.5)
		var hw := floorf(rx * sqrt(maxf(0.0, 1.0 - t * t)) + 0.3)
		_px(cx - hw, cy + y, hw * 2 + 1, 1, c)


func _draw_room() -> void:
	_px(0, 0, W, H, C_WALL)
	for row in 7:
		var y := row * 8
		_px(0, y, W, 1, C_SEAM)
		if row % 2 == 0:
			_px(0, y + 1, W, 3, C_WALL2)
		for x in range((row * 23) % 37, W, 37):
			_px(x, y, 1, 8, C_SEAM)
	# Window glow from the hall on the right.
	_px(146, 6, 10, 14, C_SEAM)
	_px(147, 7, 8, 12, Color("1d2a3a"))
	_px(150, 7, 1, 12, C_SEAM)
	_px(147, 12, 8, 1, C_SEAM)
	# Table.
	_px(0, 58, W, 2, C_TABLE_TOP)
	_px(0, 60, W, 1, Color("9a7248").darkened(0.35))
	_px(0, 61, W, 23, C_TABLE)
	for x in range(6, W, 29):
		_px(x, 61, 1, 23, C_TABLE_DARK)
	_px(0, 70, W, 1, C_TABLE_DARK.lightened(0.1))
	_px(0, 83, W, 1, C_OUT)


func _draw_mortar() -> void:
	var cx := MORTAR.x
	var by := MORTAR.y
	# Shadow and foot.
	_px(cx - 12, by, 24, 1, C_TABLE_DARK)
	_px(cx - 7, by - 3, 14, 3, C_STONE4)
	_px(cx - 7, by - 3, 14, 1, C_STONE3)
	# Bowl: bottom half of an ellipse with light from the top left.
	_ellipse(cx, by - 13, 14, 11, C_OUT, 2)
	_ellipse(cx, by - 13, 13, 10, C_STONE3, 2)
	_ellipse(cx - 2, by - 13, 9, 7, C_STONE2, 2)
	_ellipse(cx - 4, by - 13, 4, 4, C_STONE1, 2)
	_px(cx + 8, by - 9, 2, 3, C_STONE4)
	# Rim and the inside.
	_ellipse(cx, by - 13, 14, 3, C_OUT)
	_ellipse(cx, by - 13, 13, 2, C_STONE2)
	_ellipse(cx, by - 13, 11, 1, C_STONE5)
	# Contents: chunks of herbs that turn into powder.
	if step == Step.GRIND or _transfer > 0.0:
		var left := 1.0 if step == Step.GRIND else _transfer
		var powder := herb_color.lightened(0.15)
		var n := int(_chunks.size() * _grind)
		if _grind > 0.05:
			_ellipse(cx, by - 13, 1 + 9 * minf(1.0, _grind * 1.4) * left, 1, powder)
		for i in _chunks.size():
			var ch: Dictionary = _chunks[i]
			var p: Vector2 = Vector2(cx, by - 14) + ch["p"]
			if i >= n and step == Step.GRIND:
				_px(p.x, p.y - 1, ch["w"], 2, ch["c"])
				_px(p.x, p.y - 1, 1, 1, ch["c"].lightened(0.25))
			elif left > 0.3:
				_px(p.x + 1, p.y, 1, 1, powder.lightened(0.2))
	# Pestle: follows the mouse while grinding, otherwise leans on the rim.
	var tip := _pestle if step == Step.GRIND else MORTAR + Vector2(4, -13)
	if step == Step.GRIND and not _pressed:
		tip = MORTAR + Vector2(2, -12 + sin(_t * 3) * 0.6)
	var top := tip + Vector2(9, -17)
	_line(tip, top, C_OUT, 4)
	_line(tip, top, C_STONE2, 2)
	_line(tip + Vector2(-1, 0), top + Vector2(-1, 0), C_STONE1, 1)
	_px(tip.x - 2, tip.y - 1, 4, 3, C_STONE2)
	_px(tip.x - 2, tip.y - 1, 1, 2, C_STONE1)


## Pixel line (Bresenham) of the given thickness.
func _line(a: Vector2, b: Vector2, c: Color, w: int) -> void:
	var steps := int(maxf(absf(b.x - a.x), absf(b.y - a.y)))
	for i in steps + 1:
		var p := a.lerp(b, float(i) / maxf(1.0, steps))
		_px(p.x - (w - 1) / 2.0, p.y - (w - 1) / 2.0, w, w, c)


func _draw_station() -> void:
	var cx := CAULDRON.x
	# Stone hearth of the alchemy station.
	_px(cx - 20, 46, 40, 12, C_OUT)
	_px(cx - 19, 47, 38, 11, C_BRICK)
	for row in 3:
		var y := 47 + row * 4
		_px(cx - 19, y + 3, 38, 1, C_BRICK2)
		for x in range(-19 + (row % 2) * 4, 19, 8):
			_px(cx + x, y, 1, 3, C_BRICK2)
	_px(cx - 19, 47, 38, 1, C_STONE4)
	# Fire box.
	_px(cx - 10, 49, 20, 9, C_OUT)
	var heat := _temp if step >= Step.HEAT else 0.08
	if step == Step.POUR or step == Step.DONE:
		heat = 0.05
	var flames := 3 + int(heat * 9)
	for i in 9:
		var x := cx - 8 + i * 2
		var h := maxi(1, flames - absi(i - 4) + int(sin(_t * 13 + i * 1.7) * 1.5))
		h = mini(h, 9)
		for j in h:
			var k := clampi(int(float(j) / maxf(1.0, h) * 4), 0, 3)
			_px(x, 57 - j, 2, 1, C_FIRE[3 - k] if j < h - 1 else C_FIRE[0 if heat > 0.5 else 1])
	_px(cx - 9, 57, 18, 1, Color("3a1a0a"))
	# Legs of the tripod.
	_px(cx - 15, 30, 2, 17, C_IRON)
	_px(cx + 13, 30, 2, 17, C_IRON)
	# Cauldron body.
	var shake := Vector2(roundf(sin(_t * 50)) * (1 if _boil > 0 else 0), 0)
	var c := CAULDRON + shake
	_ellipse(c.x, c.y - 9, 15, 13, C_OUT, 2)
	_ellipse(c.x, c.y - 9, 14, 12, C_IRON, 2)
	_ellipse(c.x - 3, c.y - 9, 9, 8, C_IRON2, 2)
	_px(c.x - 9, c.y - 6, 2, 4, C_IRON3)
	# Rim.
	_ellipse(c.x, SURFACE_Y, 15, 4, C_OUT)
	_ellipse(c.x, SURFACE_Y, 14, 3, C_IRON3)
	_px(c.x - 15, SURFACE_Y - 1, 2, 2, C_IRON3)
	_px(c.x + 13, SURFACE_Y - 1, 2, 2, C_IRON3)
	# Liquid (goes down while pouring).
	var lc := liquid_color()
	if step < Step.POUR or _pour < 0.95:
		var level := 1.0 - (_pour if step >= Step.POUR else 0.0)
		_ellipse(c.x, SURFACE_Y + (1.0 - level) * 2, 12 * (0.4 + 0.6 * level), 2 if level > 0.5 else 1, lc)
		_px(c.x - 6, SURFACE_Y, 3, 1, lc.lightened(0.25))
	# Swirl while stirring, bubbles while hot.
	if step == Step.STIR or (step == Step.GRIND and _transfer > 0):
		for i in 5:
			var a := _stir_angle + i * TAU / 5.0
			_px(c.x + cos(a) * 9, SURFACE_Y + sin(a) * 1.5, 1, 1, herb_color.lightened(0.2))
	if step == Step.HEAT or step == Step.COOL:
		var hot := _temp if step == Step.HEAT else 1.0 - _cool
		for i in 6:
			var phase := fmod(_t * (1.5 + hot * 3) + i * 0.37, 1.0)
			if hot > 0.35 and phase < hot:
				_px(c.x - 10 + i * 4, SURFACE_Y - (1 if phase > 0.5 else 0), 1, 1, lc.lightened(0.4))
	if _boil > 0:
		for i in 4:
			_px(c.x - 15 + i * 9, SURFACE_Y + 1 + int((1.0 - _boil) * 10) + i % 2 * 2, 2, 2, lc)
	# Spoon.
	if step == Step.STIR or step == Step.HEAT:
		var a := _stir_angle if step == Step.STIR else -PI / 3
		var tip := Vector2(c.x + cos(a) * 8, SURFACE_Y + sin(a) * 1.5)
		var top := tip + Vector2(5, -16)
		_line(tip, top, C_OUT, 3)
		_line(tip, top, Color("c49a64"), 1)


func _draw_thermo() -> void:
	var r := THERMO
	_px(r.position.x - 1, r.position.y - 1, r.size.x + 2, r.size.y + 6, C_OUT)
	_px(r.position.x, r.position.y, r.size.x, r.size.y, Color("2a1c12"))
	# Green zone.
	var zy0 := r.end.y - r.size.y * HEAT_ZONE.y
	var zy1 := r.end.y - r.size.y * HEAT_ZONE.x
	_px(r.position.x, zy0, r.size.x, zy1 - zy0, C_GREEN.darkened(0.45))
	_px(r.position.x, r.position.y, r.size.x, 4, C_RED.darkened(0.4))
	# Mercury.
	var shown := _temp if step >= Step.HEAT else 0.0
	var hgt := floorf(r.size.y * clampf(shown, 0.0, 1.0))
	var in_zone := shown >= HEAT_ZONE.x and shown <= HEAT_ZONE.y
	var col := C_GREEN if in_zone else (C_RED if shown > HEAT_ZONE.y else Color("d0c0a0"))
	_px(r.position.x + 1, r.end.y - hgt, r.size.x - 2, hgt, col)
	_ellipse(r.get_center().x, r.end.y + 2, 3, 2, col)
	# Ticks.
	for i in 5:
		_px(r.end.x + 1, r.position.y + i * r.size.y / 4.0, 2, 1, C_STONE4)


func _draw_bottle() -> void:
	var bx := BOTTLE.x
	var by := BOTTLE.y
	# Round flask with a neck.
	_ellipse(bx, by - 6, 7, 6, C_STONE5)
	_ellipse(bx, by - 6, 6, 5, Color("2a3a40"))
	_px(bx - 2, by - 17, 5, 6, C_STONE5)
	_px(bx - 1, by - 17, 3, 6, Color("2a3a40"))
	var fill := _pour if step >= Step.POUR else 0.0
	if fill > 0:
		var h := int(10 * fill)
		for y in h:
			var yy := by - 1 - y
			var t := (yy - (by - 6)) / 5.0
			var hw := floorf(6 * sqrt(maxf(0.0, 1.0 - t * t)))
			_px(bx - hw, yy, hw * 2 + 1, 1, potion_color)
		# The stream from the ladle.
		if step == Step.POUR and fill < 1.0:
			_px(bx, by - 26, 1, 12, potion_color.lightened(0.2))
	_px(bx - 4, by - 9, 1, 3, Color(1, 1, 1, 0.55))
	if step == Step.DONE:
		_px(bx - 2, by - 20, 5, 3, Color("9a7248"))
		_px(bx - 2, by - 20, 5, 1, Color("c49a64"))
		var glow := 0.25 + 0.15 * sin(_t * 4)
		_ellipse(bx, by - 6, 9, 8, Color(potion_color, glow * 0.4))


func _draw_transfer() -> void:
	# Powder flying from the mortar to the cauldron after grinding.
	if _transfer <= 0:
		return
	var t := 1.0 - _transfer
	for i in 6:
		var k := clampf(t * 1.3 - i * 0.06, 0.0, 1.0)
		var a := MORTAR + Vector2(0, -16)
		var b := Vector2(CAULDRON.x, SURFACE_Y)
		var p := a.lerp(b, k) + Vector2(0, -sin(k * PI) * 14)
		if k > 0 and k < 1:
			_px(p.x + i % 3, p.y + i / 3, 1, 1, herb_color.lightened(0.2))


## Bobbing arrow above the thing to use in this step.
func _draw_pointer() -> void:
	var at := Vector2.ZERO
	match step:
		Step.GRIND:
			at = MORTAR + Vector2(0, -32)
		Step.STIR:
			at = Vector2(CAULDRON.x, 10)
		Step.HEAT:
			at = Vector2(THERMO.get_center().x, THERMO.position.y - 7)
		Step.COOL:
			at = Vector2(CAULDRON.x - 26, SURFACE_Y - 6)
		_:
			return
	if step == Step.HEAT or step == Step.STIR or step == Step.GRIND:
		var y := at.y + roundf(sin(_t * 5))
		for i in 4:
			_px(at.x - 3 + i, y + i, 7 - i * 2, 1, Color("f2c14e"))
	else:
		# A little puff face blowing on the pot.
		var x := at.x + roundf(sin(_t * 4))
		_px(x - 1, at.y, 3, 1, Color("eadbc8"))
		_px(x + 3, at.y - 1, 2, 1, Color("eadbc8", 0.6))
		_px(x + 3, at.y + 1, 2, 1, Color("eadbc8", 0.6))


func _draw_bar() -> void:
	# Four step pips and the progress of the current step.
	for i in 4:
		var done := i < step
		var cur := i == step
		var col := C_GREEN if done else (Color("f2c14e") if cur else C_TABLE_DARK)
		_px(44 + i * 6, 74, 4, 4, C_OUT)
		_px(45 + i * 6, 75, 2, 2, col)
	_px(70, 74, 52, 4, C_OUT)
	_px(71, 75, 50 * progress(), 2, Color("f2c14e"))
