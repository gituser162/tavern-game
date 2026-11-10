extends Control
## Interactive cooking in the tavern kitchen, drawn in the 320x180 pixel style of the tavern and seen from above
## (like brew_station.gd: the camera looks down on the kitchen table, the hearth / the oven, the plates):
## 1) prepare the ingredients (GameData.COOK_PREP): they are things in a basket that the cook handles himself, like on
##    the alchemy table (brew_station.gd): chop on the board with the knife in the hand, mash in the bowl with the
##    masher, crumble bread by hand, clean fish first, shake spices out; carry it to the pot / pan / dough or keep
##    it in a saucer; scraps go to the bucket;
## 2) mix, by the recipe's "method": stir the pot ("boil"), knead the dough ("bake"), season the meat ("fry");
## 3) cook it: hold the mouse to fan the fire and keep the needle in the green zone
##    (the oven heats and cools slowly; a frying roast must be flipped once halfway);
## 4) serve: click the plates (mugs for drinks) to put a portion on each one.
## Nothing is spent here: when the last portion is served the station emits `finished` and main.gd calls
## GameState.cook(). There is no way to fail: a wrong tool sends the ingredient back to the tray, overheating only
## makes the pot boil over (the pie smoke, the oil splash) and the fire calms down.

signal finished
signal step_changed(step: int)
## A short hint for the label under the title ("" = the step's normal hint).
signal message(text: String)

const GameData := preload("res://scripts/game_data.gd")
const BrewStation := preload("res://scripts/brew_station.gd")
const CraftQuality := preload("res://scripts/craft_quality.gd")

enum Step { PREP, MIX, COOK, SERVE, DONE }

const W := 200
const H := 104
const MIX_TITLES := {"boil": "Помішай у казані", "bake": "Замісь тісто", "fry": "Приправ м'ясо"}
const COOK_TITLES := {"boil": "Звари на вогні", "bake": "Спечи в печі", "fry": "Обсмаж на сковороді"}
const PREP_HINTS := {
	"boil": "Перетягуй продукти з кошика: що ріжуть, на дошку (ніж береш клацанням), ягоди й хліб у миску. Готове неси в казан або в блюдце. Коли все в казані, бери ложку.",
	"fry": "Перетягуй продукти з кошика: що ріжуть, на дошку (ніж береш клацанням), ягоди й хліб у миску. Готове неси на сковороду або в блюдце. Потім бери сільничку.",
	"bake": "Перетягуй продукти з кошика: що ріжуть, на дошку (ніж береш клацанням), ягоди й хліб у миску з тістом. Нарізане теж неси в миску. Коли все там, клацни по мисці.",
}
const SERVE_HINTS := {
	"boil": "Візьми черпак (клацни по ньому): клац по казану набирає, клац по тарілці чи кухлю наливає.",
	"fry": "Візьми лопатку (клацни по ній): клац по сковороді бере порцію, клац по тарілці кладе.",
	"bake": "Візьми лопатку (клацни по ній): клац по пирогу бере шматок, клац по тарілці кладе.",
}
const MIX_HINTS := {
	"boil": "Клацни по ложці, щоб узяти її, затисни кнопку й помішай у казані по колу: два оберти.",
	"bake": "Затисни кнопку в мисці й місі тісто: води мишею вліво-вправо.",
	"fry": "Клацни по сільничці, щоб узяти її, затисни кнопку над сковородою й потруси вліво-вправо.",
}
const COOK_HINTS := {
	"boil": "Візьми міх (клацни по ньому) і тримай кнопку миші, щоб роздмухати вогонь. Тримай стрілку в зеленій зоні. Перегрієш, і юшка збіжить: доведеться почекати.",
	"bake": "Візьми міх (клацни по ньому). Піч гріється повільно й так само повільно холоне: дмухай (тримай кнопку) і тримай стрілку в зеленій зоні, поки скоринка не зарум'яниться.",
	"fry": "Візьми міх (клацни по ньому) і тримай стрілку в зеленій зоні (кнопка миші роздмухує вогонь). Коли один бік підрум'яниться, клацни по сковороді, щоб перевернути.",
}
const OVERHEAT := {
	"boil": "Збігло! Зачекай, поки вогонь трохи спаде.",
	"bake": "Пригоряє! Піч трохи охолоне, тоді пекти далі.",
	"fry": "Олія бризкає! Вогонь трохи притухне, тоді смаж далі.",
}
const FLIP_MSG := "Один бік готовий! Клацни по сковороді, щоб перевернути."

const CHOP_CUTS := 3
const CLEANS := 3
const SPRINKLE_DISTANCE := 90.0
const TIP_SECONDS := 0.7
const FLY := 0.16
const MASH_DISTANCE := 70.0
const CRUMBLES := 3
const STIR_TURNS := 2.0
const KNEAD_DISTANCE := 150.0
const SEASON_DISTANCE := 100.0
## Heat per method: green zone, seconds to stay in it, how fast the fire rises / falls.
const HEAT := {
	"boil": {"zone": Vector2(0.58, 0.84), "secs": 2.4, "rise": 0.42, "fall": 0.22},
	"bake": {"zone": Vector2(0.5, 0.78), "secs": 3.2, "rise": 0.26, "fall": 0.11},
	"fry": {"zone": Vector2(0.6, 0.88), "secs": 2.8, "rise": 0.45, "fall": 0.24},
}
const SERVE_SECONDS := 0.35
const ICON := 16.0

# Palette taken from the tavern background (same as brew_station.gd).
const C_SEAM := Color("0b0503")
const C_TABLE_TOP := Color("6e4e30")
const C_TABLE := Color("3d2614")
const C_TABLE_DARK := Color("25150b")
const C_OUT := Color("1a0f0a")
const C_WOOD := Color("9a7248")
const C_WOOD2 := Color("c49a64")
const C_WOOD3 := Color("6a4426")
const C_STONE1 := Color("b4a894")
const C_STONE2 := Color("968a78")
const C_STONE3 := Color("7a6f60")
const C_STONE4 := Color("5e554a")
const C_STONE5 := Color("443c34")
const C_OVEN := Color("6a3a24")
const C_OVEN2 := Color("4e2a1a")
const C_IRON := Color("2a221c")
const C_IRON2 := Color("443c34")
const C_IRON3 := Color("5e554a")
const C_WATER := Color("4a7ab0")
const C_DOUGH := Color("e8d6a8")
const C_CRUST := Color("c8843a")
const C_RAW := Color("c87a6a")
const C_PLATE := Color("d8d0c0")
const C_PLATE2 := Color("a8a090")
const C_FIRE := [Color("fff0a0"), Color("f2c14e"), Color("ff8a2a"), Color("c83a1a")]
const C_GREEN := Color("7ab04e")
const C_RED := Color("c83a1a")
const C_WICKER := Color("b08a4e")
const C_LEATHER := Color("6a3a24")
const LIGHT := Vector2(-0.6, -0.8)

# Layout, seen from above (logical pixels).
const BASKET := Vector2(25, 20)
## Half-width and half-height of the oval basket.
const BASKET_RX := Vector2(22, 17)
const BIN := Vector2(86, 15)
const BIN_R := 9.0
const BOARD := Vector2(30, 62)       # centre of the cutting board
const KNIFE_REST := Vector2(50, 54)
const BOWL := Vector2(74, 64)        # centre of the bowl (mashing, crumbling, the dough)
const BOWL_R := 12.0
const SAUCERS := [Vector2(10, 92), Vector2(27, 92), Vector2(44, 92), Vector2(61, 92)]
const SAUCER_R := 7.0
const COOKER := Vector2(128, 44)     # centre of the hearth / the oven
const POT := Vector2(128, 44)        # centre of the pot and the soup in it (boil)
const PAN := Vector2(128, 44)        # centre of the pan (fry)
const LIQ_R := 13.0
const POT_R := 18.0
const PAN_R := 14.0
const HEARTH_R := 26.0
const OVEN_MOUTH := Vector2(128, 53) # middle of the oven's mouth (bake); the pie sits on the ledge in front
const PIE_AT := Vector2(128, 62)
const CHIMNEY := Vector2(133, 30)
const THERMO := Rect2(162, 18, 5, 38)
const MIX_REST := Rect2(98, 80, 24, 9)
const BELLOWS_REST := Rect2(125, 78, 20, 13)
const SERVE_REST := Rect2(148, 79, 22, 11)
const PLATES := [Vector2(178, 64), Vector2(191, 64), Vector2(178, 48), Vector2(191, 48)]
const TABLE_AREA := Rect2(2, 2, 97, 78)
const BASKET_SPOTS := [Vector2(-11, -3), Vector2(11, -3), Vector2(0, 6), Vector2(0, -8), Vector2(-11, 7),
	Vector2(11, 7), Vector2(-16, 1), Vector2(16, 1), Vector2(-5, -1), Vector2(6, -1)]
const READY := ["slices", "powder", "pulp"]

var dish_id := ""
## Quality measurements of this dish (order, heat precision, boil-overs / burns).
var quality := CraftQuality.new()
var _zone := Vector2(0.58, 0.84)
var _cuts := CHOP_CUTS
var _crumbles := CRUMBLES
var _mash := MASH_DISTANCE
var method := "boil"
var drink := false
var amount := 1
var step: int = Step.PREP
var dish_color := Color("6a9a3a")

## Things on the table (see brew_station.gd): {"id", "kind": raw | slices | powder | pulp | waste, "where": basket |
## table | board | bowl | saucer | hand | gone, "pos", "slot", "dose", "ing", "counted", "act", ...}.
var _objs: Array = []
var _held := -1
var _origin := {}
## The tool in the hand: "", knife, masher, spoon, salt, bellows, server.
var _tool := ""
## The ladle / spatula carries a portion.
var _loaded := false
var _press_pos := Vector2.ZERO
var _press_t := 0.0
var _binned := 0
var _bin_hop := 0.0
var _added := 0
var _knife := 0.0
var _masher := Vector2.ZERO
## Bits lying in the bowl / in the pot or pan: {"p": offset from the centre, "c": colour}.
var _bowl_bits: Array = []
var _pot_bits: Array = []

var _mix := 0.0
var _mix_angle := 0.0
var _knead := 0.0
var _heat := 0.0
var _temp := 0.0
var _over := 0.0
var _need_flip := false
var _flipped := false
var _flip := 0.0
var _dough_in_oven := false
var _served := 0
var _filled: Array = []
var _serve_to := -1
var _serve_t := 0.0
var _done_t := 0.0
var _pressed := false
var _mouse := Vector2(-100, -100)
var _particles: Array = []
var _t := 0.0
var _sound_mark := 0
var _transfer := 0.0
var _transfer_from := Vector2.ZERO
var _transfer_to := Vector2.ZERO
var _transfer_col := Color.WHITE

# Extra animation state (pure eye candy, never affects the result).
## Rings spreading on the soup: {"p": Vector2, "t": 0..1, "c": Color}.
var _ripples: Array = []
## Bubbles growing on the soup and popping: {"p": Vector2, "t": 0..1, "s": speed}.
var _bubbles: Array = []
## Things sliding to their place after a drop: {"i", "from", "t"}.
var _flights: Array = []
var _hop := 0.0
var _wobble := 0.0
var _stir_speed := 0.0
## Little hop of each plate when a portion lands on it (index = plate).
var _plate_hop: Array = [0.0, 0.0, 0.0, 0.0]



func _ready() -> void:
	custom_minimum_size = Vector2(W, H) * 4
	mouse_filter = Control.MOUSE_FILTER_STOP
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	set_process(false)


## Starts cooking this dish (GameData.KITCHEN_RECIPES entry); `portions` = plates to fill at the end.
func start(id: String, recipe: Dictionary, portions: int) -> void:
	dish_id = id
	method = String(recipe.get("method", "boil"))
	if not HEAT.has(method):
		method = "boil"
	drink = GameData.ITEMS[id]["cat"] == "drink"
	dish_color = Color(String(recipe.get("color", "8a6a3a")))
	amount = clampi(portions, 1, PLATES.size())
	_zone = CraftQuality.widened(HEAT[method]["zone"])
	var order := GameData.recipe_order(id)
	quality.reset(order, _zone)
	var prep := int(GameState.upgrade_value("tools", "prep"))
	_cuts = CHOP_CUTS - prep
	_crumbles = CRUMBLES - prep
	_mash = MASH_DISTANCE * (1.0 - 0.25 * prep)
	step = Step.PREP
	_mix = 0.0
	_mix_angle = -PI / 2
	_knead = 0.0
	_heat = 0.0
	_temp = 0.0
	_over = 0.0
	_need_flip = false
	_flipped = false
	_flip = 0.0
	_dough_in_oven = false
	_served = 0
	_filled.clear()
	for i in amount:
		_filled.append(false)
	_serve_to = -1
	_serve_t = 0.0
	_done_t = 0.0
	_transfer = 0.0
	_pressed = false
	_sound_mark = 0
	_held = -1
	_origin = {}
	_tool = ""
	_loaded = false
	_added = 0
	_binned = 0
	_bin_hop = 0.0
	_particles.clear()
	_ripples.clear()
	_bubbles.clear()
	_flights.clear()
	_hop = 0.0
	_wobble = 0.0
	_stir_speed = 0.0
	_plate_hop = [0.0, 0.0, 0.0, 0.0]
	_bowl_bits.clear()
	_pot_bits.clear()
	_masher = BOWL
	_objs.clear()
	# The basket is shuffled: putting things in by the recipe's order is part of the quality.
	var shuffled := order.duplicate()
	if shuffled.size() > 1:
		for attempt in 6:
			shuffled.shuffle()
			if shuffled != order:
				break
	for k in shuffled.size():
		var o := _make_obj(shuffled[k], "raw", BASKET + BASKET_SPOTS[k % BASKET_SPOTS.size()])
		o["where"] = "basket"
		o["ing"] = true
		_objs.append(o)
	set_process(true)
	step_changed.emit(step)
	queue_redraw()


func _make_obj(id: String, kind: String, pos: Vector2) -> Dictionary:
	var real := GameData.ITEMS.has(id)
	var act := String(GameData.COOK_PREP.get(id, "chop")) if real else ""
	if id in GameData.COOK_SPRINKLE:
		act = "sprinkle"
	return {
		"id": id, "kind": kind, "where": "table", "pos": pos, "home": pos, "slot": -1, "dose": 1.0, "ing": false,
		"counted": false, "act": act,
		"col": BrewStation._icon_color(id) if real else Color("8a7a66"), "tex": BrewStation.table_texture(id) if real else null,
		"work": 0.0, "hits": 0, "cuts": [], "cut_score": 1.0, "plucks": 0, "t": 0.0, "seed": randi() % 1000,
	}


func stop() -> void:
	set_process(false)
	_pressed = false
	_held = -1
	_tool = ""


## Titles of the four steps for this dish.
func titles() -> Array:
	return ["Підготуй продукти", MIX_TITLES[method], COOK_TITLES[method], "Розлий по кухлях" if drink else "Розклади по тарілках"]


## The normal hint of a step.
func hint(s: int) -> String:
	match s:
		Step.PREP:
			return PREP_HINTS[method]
		Step.MIX:
			return MIX_HINTS[method]
		Step.COOK:
			return FLIP_MSG if _need_flip else COOK_HINTS[method]
		Step.SERVE:
			return SERVE_HINTS[method]
	return "Готово!"


## 0..1 progress of the current step (for the bar under the scene).
func progress() -> float:
	match step:
		Step.PREP:
			return minf(1.0, _added / float(_ing_total()))
		Step.MIX:
			return _mix
		Step.COOK:
			return _heat
		Step.SERVE:
			return (float(_served) + (0.5 if _loaded else 0.0)) / amount
	return 1.0


func _ing_total() -> int:
	var n := 0
	for o in _objs:
		if o["ing"]:
			n += 1
	return maxi(1, n)


func _name(o: Dictionary) -> String:
	var id: String = o["id"]
	if not GameData.ITEMS.has(id):
		return "Обрізки"
	return String(GameData.ITEMS[id]["name"])


func _say(text: String) -> void:
	message.emit(text)


## The tool that mixes this dish ("" = bare hands) and its name.
func _mix_tool() -> String:
	return {"boil": "spoon", "fry": "salt", "bake": ""}[method]


# ---------- Where things are ----------


## Centre and radius of where the prepared products go (the pot, the pan, the dough bowl).
func _target_c() -> Vector2:
	return _target_point(_target())


func _over_target(p: Vector2) -> bool:
	return p.distance_to(_target_c()) < (BOWL_R + 2 if _target() == "bowl" else POT_R + 2)


## What is under the point: saucerN, basket, bin, board, bowl, cooker, table or "".
func _zone_at(p: Vector2) -> String:
	for i in SAUCERS.size():
		if p.distance_to(SAUCERS[i]) < SAUCER_R + 2:
			return "saucer%d" % i
	if _in_basket(p):
		return "basket"
	if p.distance_to(BIN) < BIN_R + 2:
		return "bin"
	if absf(p.x - BOARD.x) < 14 and absf(p.y - BOARD.y) < 9:
		return "board"
	if p.distance_to(BOWL) < BOWL_R + 2:
		return "bowl"
	if p.distance_to(COOKER) < 22 or (method == "bake" and p.distance_to(PIE_AT) < 9):
		return "cooker"
	if TABLE_AREA.has_point(p):
		return "table"
	return ""


## The tool lying at the point (not the one in the hand): knife, masher, spoon / salt, bellows, server or "".
func _tool_rest_at(p: Vector2) -> String:
	if _tool != "knife" and Rect2(KNIFE_REST.x - 3, KNIFE_REST.y - 2, 8, 18).has_point(p):
		return "knife"
	if _tool != "masher" and p.distance_to(BOWL + Vector2(11, -10)) < 5.5:
		return "masher"
	var mix := _mix_tool()
	if mix != "" and _tool != mix and MIX_REST.has_point(p):
		return mix
	if _tool != "bellows" and BELLOWS_REST.has_point(p):
		return "bellows"
	if _tool != "server" and SERVE_REST.has_point(p):
		return "server"
	return ""


## Index of the thing lying in this place ("board", "bowl", "saucer" + slot), -1 = it is free.
func _on(where: String, slot: int = -1) -> int:
	for i in _objs.size():
		if _objs[i]["where"] == where and (slot == -1 or int(_objs[i]["slot"]) == slot):
			return i
	return -1


## Index of the thing under the point that can be picked up (the nearest one), -1 = none.
func _obj_at(p: Vector2) -> int:
	var best := -1
	var best_d := 9.0
	for i in _objs.size():
		var o: Dictionary = _objs[i]
		var d := 99.0
		match String(o["where"]):
			"table", "basket":
				d = p.distance_to(o["pos"])
			"board":
				if absf(p.x - BOARD.x) < 9 and absf(p.y - BOARD.y) < 7:
					d = 0.0
			"bowl":
				if p.distance_to(BOWL) < 8:
					d = 0.0
			"saucer":
				if p.distance_to(SAUCERS[int(o["slot"])]) < SAUCER_R + 1:
					d = 0.0
		if d < best_d:
			best_d = d
			best = i
	return best


func _sprinkled(o: Dictionary) -> bool:
	return o["kind"] == "raw" and o["act"] == "sprinkle"


func _with_saucer() -> bool:
	return _held != -1 and String(_origin.get("where", "")) == "saucer"


# ---------- Input ----------


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT:
		if event.pressed and _tool != "":
			_drop_tool()
		accept_event()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_pressed = event.pressed
		_mouse = _to_logical(event.position)
		if event.pressed:
			_press_pos = _mouse
			_press_t = _t
			_on_press()
		else:
			_on_release()
		accept_event()
	elif event is InputEventMouseMotion:
		var p := _to_logical(event.position)
		if _pressed:
			_on_drag(_mouse, p)
		elif _tool == "spoon" and step == Step.MIX and p.distance_to(POT) < 26:
			_mix_angle = (p - POT).angle()
		_mouse = p


func _take_tool(tool: String) -> void:
	if _tool != "":
		_drop_tool()
	_tool = tool
	_loaded = false
	Audio.play("click")
	match tool:
		"knife":
			_say("Ніж у руці. Клацай по продукту на дошці там, де різати: %d надрізи, якомога рівніше." % _cuts)
		"masher":
			_say("Товкачик у руці. Затисни кнопку в мисці й розминай, поки не стане пюре.")
		"spoon":
			_say("Ложка в руці. Затисни кнопку в казані й мішай по колу.")
		"salt":
			_say("Сільничка в руці. Затисни кнопку над сковородою й потруси вліво-вправо.")
		"bellows":
			_say("Міх біля вогню. Тримай кнопку миші, щоб дмухати. Світла смужка посеред зеленої зони: найкраща якість.")
		"server":
			_say("Клац по страві набирає порцію, клац по %s кладе її." % ("кухлю" if drink else "тарілці"))


func _drop_tool() -> void:
	if _tool == "":
		return
	_tool = ""
	_loaded = false
	Audio.play("shelf")


func _on_press() -> void:
	match step:
		Step.PREP:
			_press_prep()
		Step.MIX:
			var mix := _mix_tool()
			if mix != "" and _tool != mix:
				if _tool_rest_at(_mouse) == mix:
					_take_tool(mix)
				else:
					_say("Візьми %s: клацни, лежить під вогнищем." % ("ложку" if mix == "spoon" else "сільничку"))
		Step.COOK:
			if _need_flip and _zone_at(_mouse) == "cooker":
				_need_flip = false
				_flipped = true
				_flip = 1.0
				Audio.play("gather")
				for k in 8:
					_particles.append({"p": _around(PAN, 6), "v": _radial(14, 26), "life": 0.4, "l0": 0.4, "c": Color("f2d070"), "drag": 4.0, "big": true})
				message.emit("")
			elif _tool != "bellows":
				if _tool_rest_at(_mouse) == "bellows":
					_take_tool("bellows")
				else:
					_say("Вогонь роздмухують міхом: клацни по ньому, він лежить під вогнищем.")
		Step.SERVE:
			if _tool != "server":
				if _tool_rest_at(_mouse) == "server":
					_take_tool("server")
				else:
					_say("Візьми %s: клацни, лежить під вогнищем." % ("черпак" if method == "boil" else "лопатку"))
				return
			if _zone_at(_mouse) == "cooker":
				if not _loaded and _served < amount:
					_loaded = true
					Audio.play("splash" if method == "boil" else "gather")
					_say("Порція набрана. Клацни по %s." % ("кухлю" if drink else "тарілці"))
			elif _serve_to == -1:
				var i := _plate_at(_mouse)
				if i != -1:
					if _loaded:
						_loaded = false
						_serve_to = i
						_serve_t = 1.0
						if _served + 1 >= amount:
							_tool = ""
						else:
							_say("Ще порція: клац по страві, клац по %s." % ("кухлю" if drink else "тарілці"))
					else:
						_say("Спершу набери порцію: клацни по страві.")


func _press_prep() -> void:
	var rest := _tool_rest_at(_mouse)
	if rest != "" and rest == _mix_tool():
		_try_mix(true)
		return
	if rest == "bellows" or rest == "server":
		_say("Це знадобиться пізніше: спершу продукти.")
		return
	if rest != "":
		_take_tool(rest)
		return
	var zone := _zone_at(_mouse)
	if _tool == "knife":
		if zone == "board":
			_cut()
			return
		_drop_tool()
	elif _tool == "masher":
		if zone == "bowl":
			_masher_press()
			return
		_drop_tool()
	var i := _obj_at(_mouse)
	if i != -1:
		_hold(i)
	elif method == "bake" and zone == "bowl":
		_try_mix(false)


func _hold(i: int) -> void:
	var o: Dictionary = _objs[i]
	_held = i
	_origin = {"where": o["where"], "pos": o["pos"], "slot": o["slot"]}
	o["where"] = "hand"
	_sound_mark = 0
	Audio.play("click")
	_say(_hint_for(o))


func _target_name() -> String:
	return {"boil": "казан", "fry": "сковороду", "bake": "миску з тістом"}[method]


## What to do with the thing just picked up.
func _hint_for(o: Dictionary) -> String:
	var id: String = o["id"]
	match String(o["kind"]):
		"waste":
			return "%s: відходи. Викинь у відро біля кошика." % ("Обрізки" if id == "_scrap" else "Порожнє")
		"slices", "powder", "pulp":
			return "Готово: неси в %s або поклади в блюдце на потім. З блюдця можна всипати й частину." % _target_name()
	if id in GameData.COOK_CLEAN and int(o["plucks"]) < CLEANS:
		return "%s: поклади на стіл і клацни %d рази, щоб почистити. Тоді на дошку." % [_name(o), CLEANS]
	match String(o["act"]):
		"chop":
			return "%s: на дошку, потім ніж." % _name(o)
		"mash":
			return "%s: у миску, потім товкачик." % _name(o)
		"crumble":
			return "%s: у миску й покриши руками (клацай по ньому)." % _name(o)
	return "%s: затисни й потруси над %s." % [_name(o), {"boil": "казаном", "fry": "сковородою", "bake": "мискою"}[method]]


func _on_release() -> void:
	if _held == -1:
		return
	var i := _held
	var o: Dictionary = _objs[i]
	var click := _mouse.distance_to(_press_pos) < 2.0 and _t - _press_t < 0.4
	if click:
		_back(o, false)
		_held = -1
		if o["kind"] == "raw" and String(o["id"]) in GameData.COOK_CLEAN and o["where"] == "table" and int(o["plucks"]) < CLEANS:
			_clean(i)
		elif o["kind"] == "raw" and o["act"] == "crumble" and o["where"] == "bowl":
			_crumble(i)
		return
	_drop(o, _zone_at(_mouse))
	_held = -1


func _back(o: Dictionary, fly: bool = true) -> void:
	var where: String = _origin.get("where", "table")
	var pos: Vector2 = _origin.get("pos", o["pos"])
	if where == "basket" and (o["kind"] != "raw" or float(o["dose"]) < 1.0):
		where = "table"
		pos = Vector2(56 + int(o["seed"]) % 16, 36 + int(o["seed"]) % 8)
	if where == "saucer" and float(o["dose"]) <= 0.001:
		o["where"] = "gone"
		return
	_place(o, where, pos, int(_origin.get("slot", -1)), fly)


func _place(o: Dictionary, where: String, pos: Vector2, slot: int = -1, fly: bool = true) -> void:
	o["where"] = where
	o["pos"] = pos
	o["slot"] = slot
	o["t"] = 0.0
	if fly:
		_flights.append({"i": _objs.find(o), "from": _mouse, "t": 0.0})


func _refuse(o: Dictionary, text: String) -> void:
	Audio.play("refuse")
	_say(text)
	_back(o)


func _drop(o: Dictionary, zone: String) -> void:
	var kind: String = o["kind"]
	var act: String = o["act"]
	var id: String = o["id"]
	if _with_saucer():
		_back(o)
		Audio.play("shelf")
		return
	if zone.begins_with("saucer"):
		var slot := int(zone.substr(6))
		if not kind in READY:
			_refuse(o, "У блюдця кладуть уже нарізане чи розім'яте.")
		elif _on("saucer", slot) != -1:
			_refuse(o, "Це блюдце зайняте.")
		else:
			_place(o, "saucer", SAUCERS[slot], slot)
			Audio.play("shelf")
			_say("У блюдці. Коли треба, перетягни блюдце над %s: воно висипається, поки тримаєш." % _target_name())
		return
	if zone == _target() and kind in READY:
		if not _enter(o, float(o["dose"])):
			_back(o)
		return
	match zone:
		"bin":
			if kind == "waste":
				o["where"] = "gone"
				_binned += 1
				_bin_hop = 1.0
				Audio.play("shelf")
				_say("")
			else:
				_refuse(o, "Це ще знадобиться. У відро йдуть лише відходи: обрізки, луска, порожні торбинки.")
		"basket":
			if kind == "raw" and float(o["dose"]) >= 1.0 and float(o["work"]) <= 0.0 and (o["cuts"] as Array).is_empty() and int(o["plucks"]) == 0 and int(o["hits"]) == 0:
				_place(o, "basket", o["home"])
			else:
				_back(o)
		"table":
			if kind in READY:
				_refuse(o, "Нарізане й розім'яте на стіл не кладуть: у блюдце або одразу в %s." % _target_name())
			else:
				_place(o, "table", _mouse.clamp(TABLE_AREA.position + Vector2(7, 7), TABLE_AREA.end - Vector2(7, 7)))
				Audio.play("shelf")
				if kind == "raw" and id in GameData.COOK_CLEAN and int(o["plucks"]) < CLEANS:
					_say("Клацни %d рази, щоб почистити." % CLEANS)
		"board":
			if kind == "raw" and act == "chop" and id in GameData.COOK_CLEAN and int(o["plucks"]) < CLEANS:
				_refuse(o, "Спершу почисть: поклади на стіл і клацни %d рази." % CLEANS)
			elif kind == "raw" and act == "chop" and _on("board") == -1:
				_place(o, "board", BOARD)
				Audio.play("shelf")
				_say("На дошці. Візьми ніж (клацни по ньому) і зроби %d надрізи. Що рівніші шматочки, то краща якість." % _cuts)
			elif kind == "raw" and act == "chop":
				_refuse(o, "Дошка зайнята: спершу прибери з неї нарізане.")
			else:
				_refuse(o, "На дошці це не ріжуть. %s" % _hint_for(o))
		"bowl":
			if _on("bowl") != -1:
				_refuse(o, "Миска зайнята: спершу закінчи з тим, що в ній.")
			elif kind == "raw" and (act == "mash" or act == "crumble"):
				_place(o, "bowl", BOWL)
				Audio.play("shelf")
				if act == "mash":
					_say("У мисці. Візьми товкачик, затисни кнопку й розминай.")
				else:
					_say("У мисці. Клацай по ньому, щоб покришити руками: %d рази." % _crumbles)
			elif _sprinkled(o):
				_back(o)
			else:
				_refuse(o, "У мисці цього не готують. %s" % _hint_for(o))
		"cooker":
			if _sprinkled(o):
				if float(o["dose"]) >= 1.0:
					_say("Не кидай: затисни кнопку й потруси вліво-вправо.")
				_back(o)
			elif kind == "waste":
				_refuse(o, "Сміття в страву не кидають: відро стоїть біля кошика.")
			elif kind in READY:
				_refuse(o, "Для пирога все йде в миску з тістом.")
			else:
				_refuse(o, "Сирим не можна. %s" % _hint_for(o))
		_:
			_back(o)


## `amount_in` (0..1 of the whole thing) of `o` goes into the pot / pan / dough.
func _enter(o: Dictionary, amount_in: float) -> bool:
	var col: Color = o["col"]
	if not o["counted"]:
		o["counted"] = true
		quality.added.append(o["id"])
		_added += 1
		Audio.play("brew")
		_landed(_target_c(), col)
		var bits: Array = _bowl_bits if _target() == "bowl" else _pot_bits
		for k in 4:
			var shade := randf_range(-0.2, 0.2)
			bits.append({"p": _around(Vector2.ZERO, 7).round(), "c": col.lightened(shade) if shade > 0 else col.darkened(-shade)})
	amount_in = minf(amount_in, float(o["dose"]))
	o["dose"] = float(o["dose"]) - amount_in
	if float(o["dose"]) <= 0.001:
		o["dose"] = 0.0
		if _sprinkled(o):
			o["kind"] = "waste"
			_say("Порожньо. Торбинку викинь у відро.")
		else:
			o["where"] = "gone"
			if _all_in():
				_say("Усе на місці. " + {"boil": "Бери ложку (під вогнищем) і мішай.", "fry": "Бери сільничку (під вогнищем).", "bake": "Клацни по мисці, щоб місити тісто."}[method])
			else:
				_say("")
	return true


func _all_in() -> bool:
	for o in _objs:
		if o["ing"] and not o["counted"]:
			return false
	return true


## Goes on to mixing if everything is in; `take` also picks the mixing tool up.
func _try_mix(take: bool) -> void:
	if step != Step.PREP or _held != -1:
		return
	if not _all_in():
		Audio.play("refuse")
		_say("Ще не все в %s. Мішати рано." % {"boil": "казані", "fry": "сковороді", "bake": "мисці"}[method])
		return
	var dose := 0.0
	var cuts := 0.0
	var n := 0
	var cut_n := 0
	var waste := 0
	for o in _objs:
		if o["kind"] == "waste" and o["where"] != "gone":
			waste += 1
		if o["ing"] and o["counted"]:
			dose += 1.0 - float(o["dose"])
			n += 1
			if not (o["cuts"] as Array).is_empty():
				cuts += float(o["cut_score"])
				cut_n += 1
	var score := dose / maxf(1.0, n)
	if cut_n > 0:
		score *= 0.4 + 0.6 * cuts / cut_n
	quality.prep = clampf(score - 0.25 * waste, 0.0, 1.0)
	_tool = ""
	_next()
	if take:
		_take_tool(_mix_tool())


## Scales and shells come off with every click; the last one leaves them on the table as waste.
func _clean(i: int) -> void:
	var o: Dictionary = _objs[i]
	o["plucks"] = int(o["plucks"]) + 1
	_hop = 1.0
	Audio.play("gather")
	var pos: Vector2 = o["pos"]
	for k in 4:
		_particles.append({"p": pos + Vector2(randf_range(-3, 3), randf_range(-3, 3)), "v": _radial(8, 18), "life": 0.4, "l0": 0.4, "c": Color("c8d0d8"), "drag": 5.0, "big": true})
	if int(o["plucks"]) >= CLEANS:
		var scrap := _make_obj("_scrap", "waste", (pos + Vector2(9, 4)).clamp(TABLE_AREA.position + Vector2(7, 7), TABLE_AREA.end - Vector2(7, 7)))
		_objs.append(scrap)
		_say("Почищено. Тепер на дошку, а луску у відро: сміття на столі псує якість.")


func _crumble(i: int) -> void:
	var o: Dictionary = _objs[i]
	o["hits"] = int(o["hits"]) + 1
	Audio.play("gather")
	_wobble = 0.15
	for k in 5:
		_particles.append({"p": _around(BOWL, 3), "v": _radial(6, 14), "life": 0.4, "l0": 0.4, "c": (o["col"] as Color).lightened(0.15), "drag": 4.0, "into": true})
	if int(o["hits"]) >= _crumbles:
		_ready_in_bowl(o, "powder")


## Something was mashed / crumbled in the bowl: for a pie it is in the dough already, else it waits to be carried.
func _ready_in_bowl(o: Dictionary, kind: String) -> void:
	o["kind"] = kind
	_sound_mark = 0
	if _tool != "":
		_drop_tool()
	Audio.play("brew")
	if _target() == "bowl":
		_enter(o, 1.0)
	else:
		_say("Готово! Неси в %s або пересип у блюдце." % _target_name())


func _cut() -> void:
	var i := _on("board")
	if i == -1 or _objs[i]["kind"] != "raw":
		_say("На дошці нічого різати: поклади туди продукт.")
		return
	var o: Dictionary = _objs[i]
	var span := BrewStation.table_span(o["id"])
	var x := clampf(_mouse.x - (BOARD.x - ICON / 2.0), span.x + 0.5, span.y - 0.5)
	var cuts: Array = o["cuts"]
	for c in cuts:
		if absf(float(c) - x) < 1.2:
			_say("Тут уже надрізано. Клацни в іншому місці.")
			return
	cuts.append(x)
	_knife = 0.15
	_hop = 1.0
	_particles.append({"p": Vector2(_mouse.x, BOARD.y + 2), "v": Vector2.ZERO, "life": 0.12, "c": Color("fff0d0"), "star": true})
	Audio.play("angry" if o["id"] == "mandrake" else "dig")
	for k in 3:
		_particles.append({"p": Vector2(_mouse.x, BOARD.y) + Vector2(randf_range(-2, 2), randf_range(-2, 2)), "v": _radial(14, 24), "life": 0.4, "l0": 0.4, "c": o["col"], "drag": 5.0, "big": true})
	if cuts.size() >= _cuts:
		cuts.sort()
		var err := 0.0
		var gap := (span.y - span.x) / (_cuts + 1.0)
		for k in cuts.size():
			err += absf(float(cuts[k]) - span.x - (k + 1) * gap) / gap
		o["cut_score"] = clampf(1.0 - err / cuts.size(), 0.0, 1.0)
		o["kind"] = "slices"
		_drop_tool()
		Audio.play("brew")
		var text := "Нарізано рівненько! " if float(o["cut_score"]) > 0.75 else "Нарізано, хоч і кривувато. "
		if String(o["id"]) in GameData.COOK_SCRAPS:
			_objs.append(_make_obj("_scrap", "waste", BOARD + Vector2(-2, -15)))
			text += "Обрізки викинь у відро. "
		_say(text + "Нарізане неси в %s або клади в блюдце." % _target_name())


func _masher_press() -> void:
	var i := _on("bowl")
	if i == -1:
		_say("У мисці нема що розминати.")
		return
	var o: Dictionary = _objs[i]
	if o["kind"] in READY:
		_drop_tool()
		_hold(i)
		return
	_masher = _clamp_to_bowl(_mouse)
	if o["act"] != "mash":
		_say("Це кришать руками: поклади товкачик (правий клац) і клацай по ньому.")


func _on_drag(from: Vector2, to: Vector2) -> void:
	match step:
		Step.PREP:
			if _tool == "masher" and to.distance_to(BOWL) < BOWL_R + 4:
				var i := _on("bowl")
				var tip := _clamp_to_bowl(to)
				if i != -1 and _objs[i]["kind"] == "raw" and _objs[i]["act"] == "mash":
					var o: Dictionary = _objs[i]
					var d := tip.distance_to(_masher)
					if d > 0.5:
						_wobble = 0.12
					o["work"] = minf(1.0, float(o["work"]) + d / _mash)
					if randf() < 0.25:
						_particles.append({"p": _around(_masher, 2), "v": _radial(8, 14), "life": 0.35, "l0": 0.35, "c": (o["col"] as Color).darkened(0.1), "drag": 5.0})
					var mark := int(float(o["work"]) * 4)
					if mark > _sound_mark:
						_sound_mark = mark
						Audio.play("gather")
					if float(o["work"]) >= 1.0:
						_ready_in_bowl(o, "pulp")
				_masher = tip
			elif _held != -1 and _sprinkled(_objs[_held]) and _over_target(to):
				var o: Dictionary = _objs[_held]
				var d := absf(to.x - from.x)
				if d > 0.0 and _enter(o, d / SPRINKLE_DISTANCE):
					if randf() < 0.6:
						var at := _clamp_to(_target_c(), to, 8) + Vector2(randf_range(-3, 3), randf_range(-2, 2))
						_particles.append({"p": at, "v": _radial(1, 5), "life": randf_range(0.25, 0.45), "l0": 0.45, "c": (o["col"] as Color).lightened(0.2), "into": true})
					var mark := int((1.0 - float(o["dose"])) * 4)
					if mark > _sound_mark:
						_sound_mark = mark
						Audio.play("gather")
		Step.MIX:
			match method:
				"boil":
					if _tool == "spoon" and to.distance_to(POT) < 26 and from.distance_to(POT) < 26:
						var a := (to - POT).angle()
						var delta := wrapf(a - _mix_angle, -PI, PI)
						_mix_angle = a
						_stir_speed = minf(1.0, _stir_speed + absf(delta) * 0.6)
						_add_mix(absf(delta) / (TAU * STIR_TURNS))
				"bake":
					if _zone_at(to) == "bowl":
						_knead = clampf(to.x - BOWL.x, -6.0, 6.0)
						_wobble = 0.1
						if absf(to.x - from.x) > 1.0 and randf() < 0.15:
							var life := 0.6
							_particles.append({"p": _around(BOWL, 5), "v": _radial(4, 9), "life": life, "l0": life, "c": Color(0.95, 0.92, 0.85, 0.7), "steam": true, "drag": 2.0})
						_add_mix(absf(to.x - from.x) / KNEAD_DISTANCE)
				"fry":
					if _tool == "salt" and _zone_at(to) == "cooker":
						var d := absf(to.x - from.x)
						if d > 0.0 and randf() < 0.6:
							var at := _clamp_to(PAN, to, 8) + Vector2(randf_range(-2, 2), randf_range(-2, 2))
							_particles.append({"p": at, "v": _radial(1, 4), "life": randf_range(0.25, 0.4), "l0": 0.4, "c": Color("f0ece0"), "into": true})
						_add_mix(d / SEASON_DISTANCE)


## True while the bellows blow into the fire.
func _pumping() -> bool:
	return step == Step.COOK and _tool == "bellows" and _pressed and _over <= 0


## A saucer held over the pot / pan / dough tips out.
func _update_prep(delta: float) -> void:
	for f in _flights:
		f["t"] = minf(1.0, float(f["t"]) + delta / FLY)
	_flights = _flights.filter(func(f: Dictionary) -> bool: return f["t"] < 1.0)
	_bin_hop = maxf(0.0, _bin_hop - delta * 4)
	if step == Step.PREP and _with_saucer() and _over_target(_mouse):
		var o: Dictionary = _objs[_held]
		if float(o["dose"]) > 0.0 and _enter(o, delta / TIP_SECONDS):
			if randf() < delta * 30:
				var at := _clamp_to(_target_c(), _mouse + Vector2(-3, 3), 8)
				_particles.append({"p": at + Vector2(randf_range(-2, 2), randf_range(-2, 2)), "v": _radial(1, 5), "life": 0.35, "l0": 0.35, "c": (o["col"] as Color).lightened(0.15), "into": true})


# ---------- Drawing (logical 200x104 pixels, seen from above) ----------


func _draw() -> void:
	draw_set_transform(_offset(), 0.0, Vector2.ONE * _scale())
	_draw_table()
	_draw_basket()
	_draw_bin()
	match method:
		"bake":
			_draw_oven()
		"fry":
			_draw_pan()
		_:
			_draw_pot()
	_draw_thermo()
	_draw_board()
	_draw_bowl()
	_draw_saucers()
	_draw_rests()
	_draw_plates()
	_draw_objects()
	_draw_bellows()
	_draw_particles()
	_draw_transfer()
	_draw_serving()
	_draw_hand()
	_draw_pointer()
	_draw_bar()
	if step >= Step.COOK:
		CraftQuality.draw_stars(_px, 152, 3, quality.quality(), _t)
	draw_set_transform(Vector2.ZERO)


func _draw_board() -> void:
	var b := BOARD
	_px(b.x - 11, b.y - 6, 25, 16, Color(0, 0, 0, 0.3))
	_px(b.x - 13, b.y - 8, 26, 16, C_OUT)
	_px(b.x - 12, b.y - 7, 24, 14, C_WOOD)
	_px(b.x - 12, b.y - 7, 24, 1, C_WOOD2)
	_px(b.x - 12, b.y - 7, 1, 14, C_WOOD2)
	for i in 3:
		_px(b.x - 10 + i * 3, b.y - 4 + i * 4, 9 + i * 2, 1, C_WOOD.darkened(0.15))
	_px(b.x + 13, b.y - 3, 4, 6, C_OUT)
	_px(b.x + 13, b.y - 2, 3, 4, C_WOOD)
	_px(b.x + 14, b.y - 1, 1, 2, C_OUT)
	if _tool == "knife":
		for k in _cuts:
			var on_board := _on("board")
			var span := BrewStation.table_span(_objs[on_board]["id"]) if on_board != -1 else Vector2(0, ICON)
			_px(roundf(b.x - ICON / 2.0 + span.x + (k + 1) * (span.y - span.x) / (_cuts + 1.0)), b.y - 8, 1, 2, C_WOOD.darkened(0.45))
	else:
		_glow_rest("knife", Rect2(KNIFE_REST.x - 2, KNIFE_REST.y - 1, 6, 16))
		_knife_at(KNIFE_REST, false)


## The tool the player should pick up now ("" = none in particular).
func _wanted_tool() -> String:
	match step:
		Step.PREP:
			if _held != -1 or _tool != "":
				return ""
			var b := _on("board")
			if b != -1 and _objs[b]["kind"] == "raw":
				return "knife"
			var m := _on("bowl")
			if m != -1 and _objs[m]["kind"] == "raw" and _objs[m]["act"] == "mash":
				return "masher"
			if _added > 0 and _all_in():
				return _mix_tool()
		Step.MIX:
			return "" if _tool == _mix_tool() else _mix_tool()
		Step.COOK:
			return "" if _tool == "bellows" or _need_flip else "bellows"
		Step.SERVE:
			return "" if _tool == "server" else "server"
	return ""


func _draw_bowl() -> void:
	var c := BOWL + Vector2(roundf(sin(_t * 70)) if _wobble > 0 else 0.0, 0)
	_ellipse(c.x + 2, c.y + 3, BOWL_R, BOWL_R - 1, Color(0, 0, 0, 0.3))
	_ellipse(c.x, c.y, BOWL_R + 1, BOWL_R + 1, C_OUT)
	_shaded(c, BOWL_R, [C_WOOD2, C_WOOD, C_WOOD3], BOWL_R - 2)
	_shaded(c, BOWL_R - 2, [C_WOOD, C_WOOD3, C_WOOD3.darkened(0.2)], 0.0, true)
	_ring_free(c, 6, C_WOOD3.darkened(0.15))
	if method == "bake" and step <= Step.MIX:
		# The dough: a pale ball that takes the filling; squashed to the side the mouse pushes while kneading.
		var sq := _knead if _pressed and step == Step.MIX else 0.0
		var rx := 6.0 + absf(sq) * 0.4
		var ry := 6.0 - absf(sq) * 0.3
		var dc := C_DOUGH.lerp(C_DOUGH.darkened(0.12), 1.0 - _mix)
		var dp := c + Vector2(sq * 0.5, 0)
		_ellipse(dp.x, dp.y, rx + 1, ry + 1, C_OUT)
		_ellipse(dp.x, dp.y, rx, ry, dc)
		_ellipse(dp.x - 2, dp.y - 2, 2, 1, dc.lightened(0.2))
		_px(dp.x - 2 + sq * 0.3, dp.y + 1, 4, 1, dc.darkened(0.12))
		for i in mini(_bowl_bits.size(), 12):
			var b: Dictionary = _bowl_bits[i]
			var bp: Vector2 = b["p"]
			_px(dp.x + clampf(bp.x * 0.6, -4, 4), dp.y + clampf(bp.y * 0.6, -4, 4), 1, 1, b["c"])
	if _tool != "masher":
		var tip := BOWL + Vector2(6, -5)
		var top := BOWL + Vector2(13, -12)
		_glow_rest("masher", Rect2(top.x - 5, top.y - 3, 8, 8))
		_masher_at(tip, top)


func _masher_at(tip: Vector2, top: Vector2) -> void:
	_px(tip.x - 2, tip.y - 1, 5, 3, C_OUT)
	_px(tip.x - 1, tip.y - 1, 3, 2, C_WOOD)
	_line(tip, top, C_OUT, 3)
	_line(tip, top, C_WOOD2, 1)
	_ellipse(top.x, top.y, 2, 2, C_OUT)
	_ellipse(top.x, top.y, 1, 1, C_WOOD2)


func _draw_saucers() -> void:
	for i in SAUCERS.size():
		var k := _on("saucer", i)
		if _with_saucer() and int(_origin.get("slot", -1)) == i:
			_ring_free(SAUCERS[i], SAUCER_R, Color(0, 0, 0, 0.25))
			continue
		_saucer_at(SAUCERS[i], false)
		if k == -1 and _held != -1 and _objs[_held]["kind"] in READY and not _with_saucer():
			_ring_free(SAUCERS[i], SAUCER_R + 2, Color(1.0, 0.85, 0.4, 0.35 + 0.2 * sin(_t * 5)))


## Spoon / salt shaker, bellows and the ladle / spatula lying on a cloth under the hearth.
func _draw_rests() -> void:
	_px(96, 77, 76, 15, Color(0, 0, 0, 0.25))
	_px(95, 76, 76, 15, Color("7a2e26"))
	_px(96, 77, 74, 13, Color("cfc4ac"))
	for i in 9:
		_px(98 + i * 8, 77, 1, 13, Color("b8ac94"))
	_px(96, 79, 74, 1, Color("a8483a"))
	_px(96, 87, 74, 1, Color("a8483a"))
	var mix := _mix_tool()
	if mix != "" and _tool != mix:
		_glow_rest(mix, MIX_REST)
		if mix == "spoon":
			var a := MIX_REST.position + Vector2(3, 5)
			var b := MIX_REST.position + Vector2(21, 3)
			_line(a, b, C_OUT, 3)
			_line(a, b, C_WOOD2, 1)
			_ellipse(a.x, a.y, 3, 2, C_OUT)
			_ellipse(a.x, a.y, 2, 1, C_WOOD)
		else:
			_salt_at(MIX_REST.get_center().round())
	if _tool != "bellows":
		_glow_rest("bellows", BELLOWS_REST)
		_bellows_at(BELLOWS_REST.position + Vector2(10, 6), Vector2(1, 0), 0.0)
	if _tool != "server":
		_glow_rest("server", SERVE_REST)
		_server_at(SERVE_REST.position + Vector2(5, 5), false, false)


func _salt_at(sp: Vector2) -> void:
	_ellipse(sp.x, sp.y, 4, 4, C_OUT)
	_ellipse(sp.x, sp.y, 3, 3, Color("e8e0d0"))
	_ellipse(sp.x, sp.y, 2, 2, C_STONE3)
	_px(sp.x - 1, sp.y, 1, 1, C_OUT)
	_px(sp.x + 1, sp.y, 1, 1, C_OUT)
	_px(sp.x, sp.y - 1, 1, 1, C_OUT)


## The serving tool with its head at `p`: a ladle for soups and drinks, a flat spatula for roasts and pies.
func _server_at(p: Vector2, lifted: bool, full: bool) -> void:
	var handle := p + (Vector2(13, 8) if lifted else Vector2(14, 3))
	if lifted:
		_shadow(p + Vector2(3, 5), 4, 3)
	_line(p, handle, C_OUT, 3)
	_line(p, handle, C_WOOD2 if method != "boil" else C_STONE3, 1)
	if method == "boil":
		var cup := 4.0 if lifted else 3.0
		_ellipse(p.x, p.y, cup + 1, cup + 1, C_OUT)
		_ellipse(p.x, p.y, cup, cup, C_IRON3)
		_ellipse(p.x, p.y, cup - 1, cup - 1, dish_color if full else C_IRON)
		if full:
			_px(p.x - 1, p.y - 1, 2, 1, dish_color.lightened(0.4))
	else:
		var s := 1.0 if lifted else 0.0
		_px(p.x - 4 - s, p.y - 3 - s, 8 + s * 2, 7 + s * 2, C_OUT)
		_px(p.x - 3 - s, p.y - 2 - s, 6 + s * 2, 5 + s * 2, C_STONE2)
		_px(p.x - 3 - s, p.y - 2 - s, 6 + s * 2, 1, C_STONE1)
		if full:
			if method == "bake":
				_draw_pie(p.x, p.y, 1.0, 0.6)
			else:
				_ellipse(p.x, p.y, 4, 2, C_OUT)
				_ellipse(p.x, p.y, 3, 1, dish_color)


func _draw_objects() -> void:
	var hover := -1
	if step == Step.PREP and not _pressed and _tool == "":
		hover = _obj_at(_mouse)
	for i in _objs.size():
		var o: Dictionary = _objs[i]
		var where: String = o["where"]
		if where == "gone" or where == "hand":
			continue
		var pos := _shown_pos(i)
		if i == hover and where != "bowl":
			_shadow(pos + Vector2(2, 4), 4, 2)
			pos += Vector2(0, -1)
		_draw_thing(o, pos, where == "bowl", 1.0)


## One thing at `pos` (its centre). `small`: inside the bowl; `lift` > 1: carried, nearer to the camera.
func _draw_thing(o: Dictionary, pos: Vector2, small: bool, lift: float) -> void:
	var col: Color = o["col"]
	var tex: Texture2D = o["tex"]
	var dose := float(o["dose"])
	var s := ICON
	match String(o["kind"]):
		"raw":
			var cuts: Array = o["cuts"]
			if not cuts.is_empty():
				_draw_slices(tex, pos, cuts, 1.0)
				for c in cuts:
					var before := 0
					for other in cuts:
						if float(other) < float(c):
							before += 1
					_px(roundf(pos.x - ICON / 2.0 - cuts.size() / 2.0 + float(c) + before), pos.y - ICON / 2.0 - 1, 1, ICON + 2, Color(0.1, 0.05, 0.02, 0.55))
			elif small and o["act"] == "mash":
				var w := float(o["work"])
				if w > 0.05:
					var pr := 1.0 + 6.0 * minf(1.0, w * 1.4)
					_ellipse(pos.x, pos.y, pr, pr, col.darkened(0.15))
					_ellipse(pos.x - 1, pos.y - 1, pr * 0.5, pr * 0.5, col.darkened(0.05))
				for k in 9:
					var a := k * 2.4 + int(o["seed"])
					var p := pos + Vector2(cos(a), sin(a)) * (1.0 + (k % 4) * 1.4)
					if k >= int(9 * w):
						_px(p.x, p.y, 2, 2, col)
						_px(p.x, p.y, 1, 1, col.lightened(0.3))
			elif small and o["act"] == "crumble":
				var k := 1.0 - 0.22 * int(o["hits"])
				for j in int(o["hits"]) * 4:
					var a := j * 1.9 + int(o["seed"])
					_px(pos.x + cos(a) * (4 + j % 3), pos.y + sin(a) * (4 + j % 3), 1, 1, col.lightened(0.15))
				draw_texture_rect(tex, Rect2(pos - Vector2(s, s) * k / 2.0, Vector2(s, s) * k), false)
			else:
				var r := Rect2(pos - Vector2(s, s) / 2.0, Vector2(s, s))
				if int(o["plucks"]) > 0 and int(o["plucks"]) < CLEANS and _hop > 0.3:
					r.position.x += roundf(sin(_t * 60))
				draw_texture_rect(tex, r, false, Color(1, 1, 1, 0.45 + 0.55 * dose) if o["act"] == "sprinkle" else Color.WHITE)
				if int(o["plucks"]) >= CLEANS:
					# Cleaned: a clean shine on it.
					_px(pos.x - 3, pos.y - 3, 2, 1, Color(1, 1, 1, 0.7))
		"slices":
			_draw_slices(tex, pos, o["cuts"], 1.5 * lift, dose)
		"powder":
			var pr := (1.5 + 3.0 * dose) * (0.85 if small else 1.0) * lift
			_ellipse(pos.x, pos.y, pr + 1, pr, col.darkened(0.25))
			_ellipse(pos.x, pos.y, pr, pr - 1, col.lightened(0.15))
			for k in 6:
				var a := k * 1.7 + int(o["seed"])
				_px(pos.x + cos(a) * pr * 0.7, pos.y + sin(a) * pr * 0.6, 1, 1, col.lightened(0.35) if k % 2 else col.darkened(0.15))
		"pulp":
			var pr := (1.5 + 3.0 * dose) * (0.85 if small else 1.0) * lift
			_ellipse(pos.x, pos.y, pr + 1, pr, col.darkened(0.4))
			_ellipse(pos.x, pos.y, pr, pr - 1, col.darkened(0.1))
			_px(pos.x - 2, pos.y - 1, 2, 1, col.lightened(0.45))
			_px(pos.x + 1, pos.y + 1, 1, 1, col.lightened(0.2))
		"waste":
			if tex == null:
				# Peels, scales and bones.
				for k in 5:
					var a := k * 1.3 + int(o["seed"])
					var p := pos + Vector2(cos(a) * 3, sin(a) * 2)
					_px(p.x, p.y, 2, 1, Color("a89a86") if k % 2 else Color("6a5a48"))
					_px(p.x + 1, p.y + 1, 1, 1, Color("d0c8b8"))
			else:
				draw_texture_rect(tex, Rect2(pos - Vector2(s, s) / 2.0, Vector2(s, s)), false, Color(0.55, 0.5, 0.45, 0.6))


## The bellows at the fire while they are in the hand: they squeeze as long as the button is held.
func _draw_bellows() -> void:
	if _tool != "bellows":
		return
	var squeeze := 0.5 + 0.5 * sin(_t * 14) if _pumping() else 0.0
	var c := Vector2(BELLOWS_REST.get_center().x, BELLOWS_REST.position.y + 3)
	_shadow(c + Vector2(2, 4), 6, 8)
	_bellows_at(c, Vector2(0, -1), squeeze)


## What is in the hand, drawn at the mouse: a carried thing (with its saucer) or a tool.
func _draw_hand() -> void:
	var m := _mouse.round()
	if _held != -1:
		var o: Dictionary = _objs[_held]
		if _with_saucer():
			var tip := _over_target(m)
			var c := m + (Vector2(-1, 1) if tip and fmod(_t * 12, 2.0) > 1.0 else Vector2.ZERO)
			_saucer_at(c, true)
			if float(o["dose"]) > 0.0:
				_draw_thing(o, c, false, 1.0)
		else:
			_shadow(m + Vector2(3, 5), 4, 2)
			var p := m + Vector2(0, -1)
			if _sprinkled(o) and _over_target(m):
				p += Vector2(0, roundf(sin(_t * 30)))
			_draw_thing(o, p, false, 1.2)
	match _tool:
		"knife":
			_knife_at(Vector2(m.x - 1, m.y - 3), _knife <= 0.0)
		"masher":
			var tip := _masher if m.distance_to(BOWL) < BOWL_R + 4 else m
			_masher_at(tip, tip + Vector2(5, -7))
		"spoon":
			if not (step == Step.MIX and m.distance_to(POT) < 26):
				_shadow(m + Vector2(3, 5), 3, 2)
				_line(m, m + Vector2(14, -14), C_OUT, 3)
				_line(m, m + Vector2(14, -14), C_WOOD2, 1)
				_ellipse(m.x, m.y, 2, 2, C_OUT)
				_ellipse(m.x, m.y, 1, 1, C_WOOD)
		"salt":
			if not (step == Step.MIX and _pressed and _zone_at(m) == "cooker"):
				_shadow(m + Vector2(3, 4), 3, 2)
				_salt_at(m)
		"server":
			_server_at(m, true, _loaded)


## Bobbing arrow above the thing to use now.
func _draw_pointer() -> void:
	var at := Vector2.ZERO
	var above_cooker := COOKER + Vector2(0, -HEARTH_R - 2)
	match _wanted_tool():
		"knife":
			at = KNIFE_REST + Vector2(1, -8)
		"masher":
			at = BOWL + Vector2(13, -21)
		"spoon", "salt":
			at = Vector2(MIX_REST.get_center().x, MIX_REST.position.y - 7)
		"bellows":
			at = Vector2(BELLOWS_REST.get_center().x, BELLOWS_REST.position.y - 6)
		"server":
			at = Vector2(SERVE_REST.get_center().x, SERVE_REST.position.y - 6)
		_:
			match step:
				Step.PREP:
					if method == "bake" and _added > 0 and _all_in() and _held == -1:
						at = BOWL + Vector2(0, -BOWL_R - 8)
				Step.MIX:
					at = BOWL + Vector2(0, -BOWL_R - 8) if method == "bake" else above_cooker
				Step.COOK:
					at = above_cooker if _need_flip else Vector2(THERMO.get_center().x, THERMO.position.y - 7)
				Step.SERVE:
					if not _loaded:
						at = PIE_AT + Vector2(0, -12) if method == "bake" else above_cooker
					else:
						var free_plate := _filled.find(false)
						if free_plate != -1:
							at = PLATES[free_plate] + Vector2(0, -13)
	if at == Vector2.ZERO:
		return
	var y := at.y + roundf(sin(_t * 5))
	for i in 4:
		_px(at.x - 3 + i, y + i, 7 - i * 2, 1, Color("f2c14e"))


func _draw_bar() -> void:
	_px(96, 94, 76, 8, Color(0, 0, 0, 0.35))
	for i in 4:
		var done := i < step
		var cur := i == step
		var col := C_GREEN if done else (Color("f2c14e") if cur else C_TABLE_DARK)
		_px(99 + i * 6, 96, 4, 4, C_OUT)
		_px(100 + i * 6, 97, 2, 2, col)
	_px(125, 96, 44, 4, C_OUT)
	_px(126, 97, 42 * progress(), 2, Color("f2c14e"))


func _scale() -> float:
	return maxf(1.0, floorf(minf(size.x / W, size.y / H)))


func _offset() -> Vector2:
	return ((size - Vector2(W, H) * _scale()) / 2).floor()


func _to_logical(p: Vector2) -> Vector2:
	return (p - _offset()) / _scale()


## Where the prepared ingredients go: the dough bowl for pies, else straight into the pot / pan.
func _target() -> String:
	return "bowl" if method == "bake" else "cooker"


## Point inside the target where the bits land.
func _target_point(target: String) -> Vector2:
	if target == "bowl":
		return BOWL
	return PAN if method == "fry" else POT


func _plate_at(p: Vector2) -> int:
	for i in amount:
		var c: Vector2 = PLATES[i]
		if not _filled[i] and p.distance_to(c) < 7:
			return i
	return -1


## A random point at most `r` from `c`.
func _around(c: Vector2, r: float) -> Vector2:
	var a := randf() * TAU
	return c + Vector2(cos(a), sin(a)) * sqrt(randf()) * r


## A velocity pointing in a random direction.
func _radial(lo: float, hi: float) -> Vector2:
	var a := randf() * TAU
	return Vector2(cos(a), sin(a)) * randf_range(lo, hi)


func _clamp_to(c: Vector2, p: Vector2, r: float) -> Vector2:
	var d := p - c
	if d.length() > r:
		d = d.normalized() * r
	return c + d


func _clamp_to_bowl(p: Vector2) -> Vector2:
	return _clamp_to(BOWL, p, 6.0)


## A ring spreading on the soup in the pot.
func _ripple(at: Vector2, col: Color) -> void:
	_ripples.append({"p": _clamp_to(POT, at, LIQ_R - 4), "t": 0.0, "c": col.lightened(0.35)})


## Something landed where it is cooked: a splash in the soup, sizzle in the pan, flour in the bowl.
func _landed(at: Vector2, col: Color) -> void:
	if method == "boil" and at.distance_to(POT) < 4:
		_ripple(at, liquid_color())
		for k in 5:
			_particles.append({"p": at, "v": _radial(16, 30), "life": 0.4, "l0": 0.4, "c": col.lerp(liquid_color(), 0.5).lightened(0.2), "drag": 5.0, "big": true})
		Audio.play("splash")
	elif method == "fry" and at.distance_to(PAN) < 4:
		for k in 6:
			_particles.append({"p": _around(at, 5), "v": _radial(12, 22), "life": 0.3, "l0": 0.3, "c": Color("f2d070"), "drag": 5.0})
		Audio.play("gather")
	else:
		for k in 5:
			var life := 0.5
			_particles.append({"p": _around(at, 5), "v": _radial(4, 10), "life": life, "l0": life, "c": Color(0.9, 0.85, 0.75, 0.6), "steam": true, "drag": 2.0})


func _add_mix(value: float) -> void:
	_mix = minf(1.0, _mix + value)
	var mark := int(_mix * 6)
	if mark > _sound_mark:
		_sound_mark = mark
		Audio.play("gather")
	if _mix >= 1.0:
		_tool = ""
		_next()


func _next() -> void:
	_sound_mark = 0
	_pressed = false
	_tool = ""
	_loaded = false
	match step:
		Step.PREP:
			message.emit("")
		Step.MIX:
			Audio.play("brew")
			if method == "bake":
				# The kneaded dough goes into the oven.
				_transfer = 1.0
				_transfer_from = BOWL
				_transfer_to = PIE_AT
				_transfer_col = C_DOUGH
				_dough_in_oven = true
		Step.COOK:
			Audio.play("buy")
			message.emit("")
	step += 1
	step_changed.emit(step)


# ---------- Simulation ----------


func _process(delta: float) -> void:
	_t += delta
	_knife = maxf(0.0, _knife - delta)
	_hop = maxf(0.0, _hop - delta * 5)
	_wobble = maxf(0.0, _wobble - delta)
	_stir_speed = maxf(0.0, _stir_speed - delta * 1.5)
	for i in _plate_hop.size():
		_plate_hop[i] = maxf(0.0, float(_plate_hop[i]) - delta * 4)
	_flip = maxf(0.0, _flip - delta * 3.0)
	if _transfer > 0:
		_transfer = maxf(0.0, _transfer - delta * 1.6)
		if _transfer <= 0:
			_landed(_transfer_to, _transfer_col)
	_update_prep(delta)
	if _over > 0:
		_over = maxf(0.0, _over - delta)
		if _over <= 0 and step == Step.COOK:
			message.emit(FLIP_MSG if _need_flip else "")
	var hp: Dictionary = HEAT[method]
	var zone: Vector2 = _zone
	match step:
		Step.COOK:
			if _over > 0:
				_temp = maxf(0.3, _temp - float(hp["fall"]) * 3 * delta)
			elif _pumping():
				_temp += float(hp["rise"]) * delta
			else:
				_temp = maxf(0.0, _temp - float(hp["fall"]) * delta)
			if _temp >= 1.0:
				_overheat()
			elif _temp >= zone.x and _temp <= zone.y and _over <= 0 and not _need_flip:
				quality.tick(delta, _temp)
				if quality.is_sweet(_temp) and randf() < delta * 8:
					# Visual cue: the right heat smells right - golden sparks over the dish.
					_particles.append({"p": _around(COOKER, 8), "v": Vector2(randf_range(-3, 3), randf_range(-9, -5)), "life": 0.6, "c": Color("fff0a0"), "star": true, "drag": 1.5})
				_heat = minf(1.0, _heat + delta / float(hp["secs"]))
				if method == "fry" and not _flipped and _heat >= 0.5:
					_need_flip = true
					Audio.play("event")
					message.emit(FLIP_MSG)
				if _heat >= 1.0:
					_next()
			if _need_flip and randf() < delta * 10:
				var life := 1.0
				_particles.append({"p": _around(PAN, 5), "v": Vector2(randf_range(2, 6), randf_range(-6, -2)), "life": life, "l0": life, "c": Color(0.45, 0.42, 0.4, 0.5), "steam": true})
		Step.SERVE:
			_temp = maxf(0.0, _temp - delta * 0.2)
			if _serve_to != -1:
				_serve_t += delta / SERVE_SECONDS
				if _serve_t >= 1.0:
					_filled[_serve_to] = true
					_plate_hop[_serve_to] = 1.0
					var pp: Vector2 = PLATES[_serve_to]
					for k in 5:
						_particles.append({"p": pp, "v": _radial(10, 18), "life": 0.3, "l0": 0.3, "c": dish_color.lightened(0.3), "drag": 5.0})
					_served += 1
					_serve_to = -1
					Audio.play("pour" if drink or method == "boil" else "shelf")
					if _served >= amount:
						step = Step.DONE
						Audio.play("buy")
						step_changed.emit(step)
		Step.DONE:
			_done_t += delta
			if _done_t > 0.05 and _done_t - delta <= 0.05:
				# Everything is served: the plates jump and sparkle.
				for i in amount:
					_plate_hop[i] = 1.0
					var pp: Vector2 = PLATES[i]
					for k in 5:
						var a := k * TAU / 5.0 + randf() * 0.5
						_particles.append({"p": pp, "v": Vector2(cos(a), sin(a)) * randf_range(14, 24), "life": randf_range(0.4, 0.6), "c": Color("f2c14e").lightened(randf_range(0.0, 0.4)), "star": k % 2 == 0, "drag": 2.5})
			if _done_t > 0.2 and _done_t - delta <= 0.2:
				finished.emit()
	# Steam over a hot dish (rises to the camera, swells and drifts off), sizzle in the pan.
	var hot := _temp if step >= Step.COOK else 0.0
	if hot > 0.2 and randf() < hot * delta * 12:
		var sp := _around(POT, LIQ_R - 2)
		if method == "fry":
			sp = _around(PAN, 7)
		elif method == "bake":
			sp = _around(PIE_AT, 4)
		var life := randf_range(0.8, 1.4)
		_particles.append({"p": sp, "v": Vector2(randf_range(3, 8), randf_range(-7, -3)), "life": life, "l0": life, "c": Color(0.85, 0.82, 0.78, 0.4), "steam": true, "sway": randf() * TAU})
	if step == Step.COOK and method == "fry" and _temp > 0.4 and randf() < _temp * delta * 8:
		_particles.append({"p": _around(PAN, PAN_R - 3), "v": _radial(8, 16), "life": 0.25, "l0": 0.25, "c": Color("f2d070"), "drag": 5.0, "big": true})
	_update_fire_fx(delta)
	_update_surface(delta, hot)
	# Hot food on the plates keeps steaming a little.
	if step >= Step.SERVE:
		for i in amount:
			if _filled[i] and randf() < delta * 2.5:
				var pp: Vector2 = PLATES[i]
				var life := randf_range(0.7, 1.1)
				_particles.append({"p": _around(pp, 3), "v": Vector2(randf_range(1, 4), randf_range(-5, -2)), "life": life, "l0": life, "c": Color(0.85, 0.82, 0.78, 0.35), "steam": true, "sway": randf() * TAU})
	for p in _particles:
		var v: Vector2 = p["v"]
		if p.has("drag"):
			v *= maxf(0.0, 1.0 - float(p["drag"]) * delta)
		p["v"] = v
		p["life"] = float(p["life"]) - delta
		var pos: Vector2 = Vector2(p["p"]) + v * delta
		if p.has("sway"):
			pos.y += sin(_t * 4 + float(p["sway"])) * 3 * delta
		p["p"] = pos
		# Grains and crumbs fall onto the soup and make a ring on it.
		if p.get("into", false) and float(p["life"]) <= 0.0 and method == "boil" and pos.distance_to(POT) < LIQ_R and randf() < 0.5:
			_ripple(pos, liquid_color())
	_particles = _particles.filter(func(p): return p["life"] > 0)
	queue_redraw()


## Embers from the hearth, air blown into the fire while fanning, smoke from the oven chimney.
func _update_fire_fx(delta: float) -> void:
	var fire := _fire_heat()
	if method == "bake":
		if randf() < delta * (0.8 + fire * 5):
			var life := randf_range(1.0, 1.6)
			_particles.append({"p": CHIMNEY + _radial(0, 1), "v": Vector2(randf_range(4, 8), randf_range(-6, -3)), "life": life, "l0": life, "c": Color(0.35, 0.32, 0.3, 0.45 + 0.2 * fire), "steam": true, "sway": randf() * TAU})
		if fire > 0.2 and randf() < delta * fire * 10:
			_particles.append({"p": OVEN_MOUTH + Vector2(randf_range(-7, 7), 1), "v": Vector2(randf_range(-4, 4), randf_range(5, 12)), "life": randf_range(0.3, 0.6), "c": C_FIRE[1], "ember": true, "sway": randf() * TAU})
	elif randf() < delta * (1.0 + fire * 16):
		var a := randf() * TAU
		var dir := Vector2(cos(a), sin(a))
		_particles.append({"p": COOKER + dir * (POT_R + 2), "v": dir * randf_range(6, 14) * (0.6 + fire) + Vector2(0, -3), "life": randf_range(0.5, 1.0), "c": C_FIRE[1], "ember": true, "sway": randf() * TAU})
	if _pumping() and randf() < delta * 16:
		var life := 0.3
		_particles.append({"p": Vector2(BELLOWS_REST.get_center().x + randf_range(-2, 2), BELLOWS_REST.position.y - 7), "v": Vector2(randf_range(-8, 8), randf_range(-45, -30)), "life": life, "l0": life, "c": Color(0.9, 0.86, 0.8, 0.5), "air": true})


## Bubbles on the boiling soup, rings from the spoon.
func _update_surface(delta: float, hot: float) -> void:
	if method == "boil" and step >= Step.COOK and hot > 0.3 and randf() < delta * hot * 9:
		_bubbles.append({"p": _around(POT, LIQ_R - 3), "t": 0.0, "s": randf_range(0.7, 1.2)})
	for b in _bubbles:
		b["t"] = float(b["t"]) + delta * (1.2 + hot * 2.0) * float(b["s"])
		if b["t"] >= 1.0:
			for k in 3:
				_particles.append({"p": Vector2(b["p"]), "v": _radial(6, 12), "life": 0.2, "l0": 0.2, "c": liquid_color().lightened(0.4), "drag": 6.0})
	_bubbles = _bubbles.filter(func(b): return b["t"] < 1.0)
	if method == "boil" and step == Step.MIX and _stir_speed > 0.15:
		if randf() < delta * 10 * _stir_speed:
			_ripple(POT + Vector2(cos(_mix_angle), sin(_mix_angle)) * 7, liquid_color())
		if _stir_speed > 0.55 and randf() < delta * 6:
			var a := _mix_angle + randf_range(-0.4, 0.4)
			var dir := Vector2(cos(a), sin(a))
			_particles.append({"p": POT + dir * (LIQ_R - 1), "v": (dir + dir.orthogonal() * 0.6) * randf_range(14, 22), "life": 0.45, "l0": 0.45, "c": liquid_color().lightened(0.2), "drag": 4.0, "big": true})
	for r in _ripples:
		r["t"] = float(r["t"]) + delta * 1.8
	_ripples = _ripples.filter(func(r): return r["t"] < 1.0)


func _overheat() -> void:
	_temp = 1.0
	_over = 1.0
	quality.boils += 1
	Audio.play("error")
	message.emit(OVERHEAT[method] + " Якість падає.")
	if method == "bake":
		for i in 10:
			var life := randf_range(0.7, 1.1)
			_particles.append({"p": OVEN_MOUTH + Vector2(randf_range(-8, 8), 0), "v": Vector2(randf_range(-6, 6), randf_range(4, 14)), "life": life, "l0": life, "c": Color(0.2, 0.18, 0.16, 0.8), "steam": true})
		return
	var col := liquid_color().lightened(0.2) if method == "boil" else Color("f2d070")
	var r := LIQ_R + 1 if method == "boil" else PAN_R - 2
	for i in 12:
		var a := i * TAU / 12.0 + randf_range(-0.2, 0.2)
		var dir := Vector2(cos(a), sin(a))
		_particles.append({"p": COOKER + dir * r, "v": dir * randf_range(14, 28), "life": 0.6, "l0": 0.6, "c": col, "drag": 3.5, "big": true})


## Colour of the soup in the pot (boil).
func liquid_color() -> Color:
	var dark := dish_color.darkened(0.35)
	match step:
		Step.PREP:
			return C_WATER.lerp(dark, 0.4 * _added / maxf(1.0, _ing_total()))
		Step.MIX:
			return C_WATER.lerp(dark, 0.4).lerp(dark, _mix)
		Step.COOK:
			var c := dark.lerp(dish_color, _heat)
			if _temp > _zone.y:
				c = c.lerp(Color("2a2018"), 0.5 * (_temp - _zone.y) / maxf(0.05, 1.0 - _zone.y))
			return c
	return dish_color


## How browned the dish is (0 raw .. 1 done).
func _doneness() -> float:
	if step == Step.COOK:
		return _heat
	return 1.0 if step > Step.COOK else 0.0


# ---------- Drawing (logical 160x84 pixels, seen from above) ----------


## Quality of the dish so far (GameData.QUALITY).
func current_quality() -> int:
	return quality.quality()


func _draw_particles() -> void:
	for p in _particles:
		var c: Color = p["c"]
		var life: float = p["life"]
		var pos: Vector2 = p["p"]
		var k := clampf(life / float(p.get("l0", 1.0)), 0.0, 1.0)
		if p.has("steam"):
			var s := 1.0 + floorf((1.0 - k) * 2.5)
			_px(pos.x - floorf(s / 2), pos.y - floorf(s / 2), s, s, Color(c, c.a * k))
			continue
		if p.has("air"):
			_px(pos.x, pos.y, 2 + floorf(k * 2), 1, Color(c, c.a * k))
			continue
		if p.has("ember"):
			c = C_FIRE[1] if life > 0.6 else (C_FIRE[2] if life > 0.3 else C_FIRE[3])
		if p.get("star", false) and life > 0.15:
			_px(pos.x - 1, pos.y, 3, 1, Color(c, c.a * 0.7))
			_px(pos.x, pos.y - 1, 1, 3, Color(c, c.a * 0.7))
		if (p.get("into", false) and k > 0.5) or (p.get("big", false) and k > 0.55):
			_px(pos.x, pos.y, 2, 2, c)
		else:
			_px(pos.x, pos.y, 1, 1, c)


func _shadow(c: Vector2, rx: float, ry: float) -> void:
	_ellipse(c.x, c.y, rx, ry, Color(0, 0, 0, 0.25))


## Circle outline made of single pixels, clipped to the soup.
func _ring(c: Vector2, r: float, col: Color) -> void:
	var n := maxi(8, int(r * 6))
	for i in n:
		var a := i * TAU / n
		var p := (c + Vector2(cos(a), sin(a)) * r).round()
		if p.distance_to(POT) <= LIQ_R - 0.5:
			_px(p.x, p.y, 1, 1, col)


## Circle outline (not clipped).
func _ring_free(c: Vector2, r: float, col: Color) -> void:
	var n := maxi(8, int(r * 6))
	for i in n:
		var a := i * TAU / n
		_px(roundf(c.x + cos(a) * r), roundf(c.y + sin(a) * r), 1, 1, col)


## Warm flickering light of the fire spreading over the table.
func _draw_fire_light(c: Vector2) -> void:
	var fire := _fire_heat()
	var flick := 0.85 + 0.15 * sin(_t * 9) * sin(_t * 5.3)
	_ellipse(c.x, c.y, 44, 36, Color(1.0, 0.5, 0.15, (0.03 + 0.1 * fire) * flick))
	_ellipse(c.x, c.y, 34, 30, Color(1.0, 0.55, 0.2, (0.03 + 0.08 * fire) * flick))


func _px(x: float, y: float, w: float, h: float, c: Color) -> void:
	draw_rect(Rect2(floorf(x), floorf(y), w, h), c)


## Filled ellipse made of whole-pixel rows.
func _ellipse(cx: float, cy: float, rx: float, ry: float, c: Color) -> void:
	for y in range(-int(ry), int(ry) + 1):
		var t := float(y) / (ry + 0.5)
		var hw := floorf((rx + 0.5) * sqrt(maxf(0.0, 1.0 - t * t)))
		_px(cx - hw, cy + y, hw * 2 + 1, 1, c)


## A disc / ring lit from the top left (see brew_station.gd).
func _shaded(c: Vector2, r: float, cols: Array, inner: float = 0.0, concave: bool = false) -> void:
	var n := cols.size()
	for y in range(-int(r), int(r) + 1):
		for x in range(-int(r), int(r) + 1):
			var d := Vector2(x, y).length()
			if d > r + 0.3 or d < inner - 0.3:
				continue
			var dot := (Vector2(x, y) / maxf(1.0, r)).dot(LIGHT)
			if concave:
				dot = -dot
			var k := clampi(int((1.0 - dot) * 0.5 * n), 0, n - 1)
			_px(c.x + x, c.y + y, 1, 1, cols[k])


## Pixel line of the given thickness.
func _line(a: Vector2, b: Vector2, c: Color, w: int) -> void:
	var steps := int(maxf(absf(b.x - a.x), absf(b.y - a.y)))
	for i in steps + 1:
		var p := a.lerp(b, float(i) / maxf(1.0, steps))
		_px(p.x - (w - 1) / 2.0, p.y - (w - 1) / 2.0, w, w, c)


## The kitchen table seen from above: planks, a few garlic heads and a towel lying about.
func _draw_table() -> void:
	_px(0, 0, W, H, C_TABLE)
	for row in range(0, 11):
		var y := row * 10 - 2
		_px(0, y, W, 1, C_TABLE_DARK)
		_px(0, y + 1, W, 1, C_TABLE_TOP.darkened(0.25))
		var off := (row * 47) % 61
		for x in range(off, W, 61):
			_px(x, y, 1, 10, C_TABLE_DARK)
			_px(x + 2, y + 4, 1, 1, C_SEAM)
		for g in 4:
			var gx := (row * 31 + g * 43) % W
			_px(gx, y + 3 + (g * 3) % 6, 6 + g * 2, 1, C_TABLE.darkened(0.2))
	_px(0, 0, W, 1, C_SEAM)
	_px(0, H - 1, W, 1, C_SEAM)
	# A linen towel at the right edge.
	_px(176, 4, 22, 14, Color(0, 0, 0, 0.25))
	_px(175, 3, 22, 14, Color("cfc4ac"))
	for i in 3:
		_px(175, 5 + i * 4, 22, 1, Color("a8483a"))
	_px(175, 3, 22, 1, Color("e8dcc4"))


func _fire_heat() -> float:
	if step == Step.COOK:
		return _temp
	if step > Step.COOK:
		return maxf(0.05, _temp * 0.5)
	return 0.08


## Stone hearth ring with the fire pit; flames lick out from under whatever stands on it (radius `inner`).
func _draw_hearth(inner: float) -> void:
	var c := COOKER
	_draw_fire_light(c)
	_ellipse(c.x + 1, c.y + 2, HEARTH_R, HEARTH_R, Color(0, 0, 0, 0.3))
	_ellipse(c.x, c.y, HEARTH_R + 1, HEARTH_R + 1, C_OUT)
	_shaded(c, HEARTH_R, [C_STONE2, C_STONE3, C_STONE4, C_STONE5], HEARTH_R - 5)
	for i in 14:
		var a := i * TAU / 14.0 + 0.2
		var dir := Vector2(cos(a), sin(a))
		_line(c + dir * (HEARTH_R - 5), c + dir * HEARTH_R, C_OUT, 1)
	_ellipse(c.x, c.y, HEARTH_R - 5, HEARTH_R - 5, Color("1a0a05"))
	var heat := _fire_heat()
	for i in 40:
		var a := i * TAU / 40.0
		var dir := Vector2(cos(a), sin(a))
		var len := 1.0 + heat * 4.0 + sin(_t * 13 + i * 1.7) * 1.2 + sin(_t * 7.3 + i * 0.9)
		len = clampf(len, 0.0, HEARTH_R - 5 - inner)
		var coal := C_FIRE[3].darkened(0.4) if (i * 7) % 3 else C_FIRE[3].darkened(0.1)
		_px(roundf(c.x + dir.x * (HEARTH_R - 6)), roundf(c.y + dir.y * (HEARTH_R - 6)), 1, 1, coal)
		for j in int(len):
			var k := float(j) / maxf(1.0, len)
			var col: Color = C_FIRE[0 if heat > 0.5 and j == 0 else 1] if k < 0.3 else (C_FIRE[2] if k < 0.7 else C_FIRE[3])
			var p := c + dir * (inner + 0.5 + j)
			_px(roundf(p.x), roundf(p.y), 1, 1, col)


func _draw_pot() -> void:
	_draw_hearth(POT_R)
	var shake := Vector2(roundf(sin(_t * 50)) * (1 if _over > 0 else 0), 0)
	var c := POT + shake
	var fire := _fire_heat()
	# Wide cooking pot with two ears.
	for side in [-1.0, 1.0]:
		_ellipse(c.x + side * (POT_R + 1), c.y, 2, 3, C_OUT)
		_px(c.x + side * (POT_R + 1) - 1, c.y - 2, 2, 4, C_IRON3)
	_ellipse(c.x, c.y, POT_R + 1, POT_R + 1, C_OUT)
	_shaded(c, POT_R, CraftQuality.pot_colors([C_IRON3, C_IRON2, C_IRON, C_IRON.darkened(0.3)]), LIQ_R + 1)
	if fire > 0.2:
		for i in 36:
			var a := i * TAU / 36.0
			var p := c + Vector2(cos(a), sin(a)) * POT_R
			_px(roundf(p.x), roundf(p.y), 1, 1, Color(1.0, 0.5, 0.15, 0.2 + 0.4 * fire))
	# Soup (goes down while serving).
	_ellipse(c.x, c.y, LIQ_R + 1, LIQ_R + 1, C_IRON.darkened(0.4))
	var lc := liquid_color()
	var level := 1.0
	if step >= Step.SERVE:
		level = 1.0 - float(_served) / amount * 0.8
	var lr := LIQ_R * (0.55 + 0.45 * level)
	var lo := Vector2(1, 1) * (1.0 - level) * 2.0
	_ellipse(c.x + lo.x, c.y + lo.y, lr, lr, lc)
	_ellipse(c.x + lo.x + 1, c.y + lo.y + 1, lr - 2, lr - 2, lc.darkened(0.08))
	var g := c + Vector2(-6, -6) * (lr / LIQ_R) + Vector2(roundf(sin(_t * 0.9) * 1.5), 0)
	_px(g.x, g.y, 3, 1, lc.lightened(0.3))
	_px(g.x - 1, g.y + 1, 2, 1, lc.lightened(0.18))
	if step == Step.MIX and _stir_speed > 0.3:
		for j in 10:
			var a := _mix_angle * 1.6 + j * 0.7
			var r := j * 0.6
			_px(c.x + cos(a) * r, c.y + sin(a) * r, 1, 1, lc.darkened(0.25 + 0.03 * (10 - j)))
	for r in _ripples:
		var t: float = r["t"]
		var col: Color = r["c"]
		_ring(Vector2(r["p"]) + shake, 1.0 + t * 6.0, Color(col, 0.8 * (1.0 - t)))
	# Bits floating; they swirl while stirring.
	var spin := _mix_angle if step == Step.MIX else _t * 0.5
	for i in _pot_bits.size():
		var b: Dictionary = _pot_bits[i]
		var off: Vector2 = b["p"]
		if step >= Step.MIX:
			var a := spin + i * TAU / maxf(1.0, _pot_bits.size())
			var rr := (4.0 + i % 3 * 3) * lr / LIQ_R
			off = Vector2(cos(a), sin(a)) * rr
		_px(c.x + off.x, c.y + off.y, 1, 1, b["c"])
	for b in _bubbles:
		var t: float = b["t"]
		var bp: Vector2 = Vector2(b["p"]) + shake
		if t < 0.45:
			_px(bp.x, bp.y, 1, 1, lc.lightened(0.35))
		else:
			_px(bp.x - 1, bp.y, 3, 1, lc.lightened(0.3))
			_px(bp.x, bp.y - 1, 1, 3, lc.lightened(0.3))
			_px(bp.x, bp.y, 1, 1, lc.lightened(0.15))
			_px(bp.x - 1, bp.y - 1, 1, 1, lc.lightened(0.7) if t > 0.8 else lc.lightened(0.5))
	if _over > 0:
		for i in 14:
			var a := i * TAU / 14.0 + sin(_t * 3 + i) * 0.1
			var p := c + Vector2(cos(a), sin(a)) * (LIQ_R + 1)
			_px(p.x - 1, p.y - 1, 3, 2, Color(lc.lightened(0.45), _over))
		for i in 6:
			var a := i * TAU / 6.0 + 0.4
			var p := c + Vector2(cos(a), sin(a)) * (LIQ_R + 2 + (1.0 - _over) * 6)
			_px(p.x, p.y, 2, 2, Color(lc, minf(1.0, _over * 2)))
	# Wooden spoon across the rim; a ladle while serving.
	if step == Step.MIX and _tool == "spoon" and _mouse.distance_to(POT) < 26:
		var a := _mix_angle
		var dir := Vector2(cos(a), sin(a))
		var tip := c + dir * 7
		var end := c + dir.rotated(-0.15 * _stir_speed) * (POT_R + 9)
		_line(tip, end, C_OUT, 3)
		_line(tip, end, C_WOOD2, 1)
		_ellipse(tip.x, tip.y, 2, 2, C_OUT)
		_ellipse(tip.x, tip.y, 1, 1, C_WOOD)



func _draw_pan() -> void:
	_draw_hearth(PAN_R)
	var c := COOKER
	# Grate bars over the fire.
	for i in 5:
		var x := c.x - 16 + i * 8
		_px(x, c.y - 20, 1, 40, C_IRON3)
	var shake := Vector2(roundf(sin(_t * 50)) * (1 if _over > 0 else 0), 0)
	var p := PAN + shake
	# Long handle to the top left.
	var h0 := p + Vector2(-PAN_R + 2, -PAN_R + 4)
	var h1 := p + Vector2(-PAN_R - 12, -PAN_R - 6)
	_line(h0, h1, C_OUT, 4)
	_line(h0, h1, C_IRON3, 2)
	_px(h1.x - 1, h1.y - 1, 3, 3, C_OUT)
	# Pan: dark iron dish, a lit rim, the oiled bottom.
	_ellipse(p.x, p.y, PAN_R + 1, PAN_R + 1, C_OUT)
	_shaded(p, PAN_R, [C_IRON3, C_IRON2, C_IRON], PAN_R - 2)
	_ellipse(p.x, p.y, PAN_R - 2, PAN_R - 2, C_IRON)
	_ellipse(p.x + 1, p.y + 1, PAN_R - 4, PAN_R - 4, C_IRON.darkened(0.2))
	# Oil shines when hot.
	if step == Step.COOK and _temp > 0.3:
		_px(p.x - 8, p.y - 7, 4, 1, Color("c8a040", 0.6 * _temp))
		_px(p.x + 5, p.y + 6, 3, 1, Color("c8a040", 0.4 * _temp))
	# The meat: raw pink, browned side by side. Flipped, it jumps towards the camera and turns over.
	var d := _doneness()
	var top_side := C_RAW
	var under := C_RAW.lerp(dish_color, minf(1.0, d * 2.0))
	if _flipped:
		top_side = dish_color
		under = C_RAW.lerp(dish_color, clampf(d * 2.0 - 1.0, 0.0, 1.0))
	if step > Step.COOK:
		top_side = dish_color
	var hop := sin((1.0 - _flip) * PI) if _flip > 0 else 0.0
	var showing := top_side
	if _flip > 0.5:
		showing = C_RAW.lerp(dish_color, 0.5)
	var jig := 1.0 if step == Step.COOK and _temp > 0.5 and fmod(_t * (6 + _temp * 8), 2.0) > 1.7 else 0.0
	var portions := 1 if step < Step.SERVE else amount - _served
	if portions > 0:
		var mp := p + Vector2(jig, -hop * 4)
		var rx := 7.0 + hop * 3
		var ry := 5.0 * (1.0 - 0.6 * absf(sin(_flip * PI))) + hop * 2
		if hop > 0:
			_shadow(p + Vector2(1, 2), 7, 5)
		_ellipse(mp.x, mp.y, rx + 1, ry + 1, C_OUT)
		_ellipse(mp.x, mp.y, rx, ry, showing)
		# Seared edge (the side under the meat shows at the rim).
		_ring_free(mp, maxf(1.0, ry), under.darkened(0.1))
		_ellipse(mp.x - 2, mp.y - 1, 2, 1, showing.lightened(0.15))
		# Seasoning and roots on top.
		for b in _pot_bits:
			var off: Vector2 = b["p"]
			_px(mp.x + clampf(off.x, -5, 5), mp.y + clampf(off.y, -3, 3), 1, 1, b["c"])
	# A salt shaker in the hand while seasoning.
	if step == Step.MIX and _tool == "salt" and _pressed and _zone_at(_mouse) == "cooker":
		var sp := _clamp_to(PAN, _mouse, 9)
		sp += Vector2(roundf(sin(_t * 30)) if _pressed else 0.0, 0)
		_shadow(sp + Vector2(3, 4), 3, 2)
		_ellipse(sp.x, sp.y, 4, 4, C_OUT)
		_ellipse(sp.x, sp.y, 3, 3, Color("e8e0d0"))
		_ellipse(sp.x, sp.y, 2, 2, C_STONE3)
		_px(sp.x - 1, sp.y, 1, 1, C_OUT)
		_px(sp.x + 1, sp.y, 1, 1, C_OUT)
		_px(sp.x, sp.y - 1, 1, 1, C_OUT)


## A clay dome oven seen from above on its stone base: the chimney on top, the mouth to the front
## with a stone ledge where the pie bakes in the glow.
func _draw_oven() -> void:
	var c := COOKER + Vector2(0, -6)
	# Stone base.
	_px(c.x - 25, c.y - 22, 52, 56, Color(0, 0, 0, 0.3))
	_px(c.x - 26, c.y - 24, 52, 56, C_OUT)
	_px(c.x - 25, c.y - 23, 50, 54, C_STONE4)
	for row in 7:
		var y := c.y - 23 + row * 7 + 6
		_px(c.x - 25, y, 50, 1, C_STONE5)
		for x in range(-25 + (row % 2) * 6, 25, 12):
			_px(c.x + x, y - 6, 1, 6, C_STONE5)
	_px(c.x - 25, c.y - 23, 50, 1, C_STONE3)
	# Fire glow on the ledge in front of the mouth.
	var heat := _fire_heat()
	var flick := 0.85 + 0.15 * sin(_t * 9) * sin(_t * 5.3)
	_ellipse(OVEN_MOUTH.x, OVEN_MOUTH.y + 9, 14, 6, Color(1.0, 0.5, 0.15, (0.1 + 0.35 * heat) * flick))
	# Dome: round clay vault over the mouth, rings of clay, the chimney hole.
	_ellipse(c.x, c.y, 21, 19, C_OUT)
	_shaded(c, 19, [C_OVEN.lightened(0.15), C_OVEN, C_OVEN2, C_OVEN2.darkened(0.2)])
	for r in [8.0, 14.0]:
		_ring_free(c, r, C_OVEN2)
	_px(c.x - 9, c.y - 10, 4, 1, C_OVEN.lightened(0.25))
	_ellipse(CHIMNEY.x, CHIMNEY.y, 4, 4, C_OUT)
	_ellipse(CHIMNEY.x, CHIMNEY.y, 3, 3, C_OVEN2)
	_ellipse(CHIMNEY.x, CHIMNEY.y, 2, 2, Color("140804"))
	_ellipse(CHIMNEY.x, CHIMNEY.y, 1, 1, Color(1.0, 0.4, 0.1, 0.2 + 0.5 * heat))
	# The mouth: an arched opening cut into the front of the dome, the fire glowing at the back.
	var m := OVEN_MOUTH
	_ellipse(m.x, m.y, 11, 5, C_OUT)
	_px(m.x - 11, m.y, 23, 3, C_OUT)
	_ellipse(m.x, m.y, 10, 4, Color("1a0a05"))
	_px(m.x - 10, m.y, 21, 2, Color("1a0a05"))
	_ellipse(m.x, m.y, 10, 4, Color(1.0, 0.45, 0.15, 0.15 + 0.45 * heat))
	for i in 9:
		var x := m.x - 9 + i * 2
		var h := maxi(1, int(1 + heat * 3 + sin(_t * 13 + i * 1.7) * 1.2))
		for j in h:
			_px(x, m.y - 3 + j, 2, 1, C_FIRE[clampi(3 - h + j + 1, 0, 3)] if j < h - 1 else C_FIRE[0 if heat > 0.5 else 1])
	_px(m.x - 11, m.y + 2, 23, 1, C_STONE2)
	# The pie on the ledge: pale dough that browns.
	if _dough_in_oven and _transfer <= 0.15:
		var portions := 1 if step < Step.SERVE else amount - _served
		if portions > 0:
			# The pie rises a little while it bakes.
			_draw_pie(PIE_AT.x, PIE_AT.y, _doneness(), 1.0 + 0.12 * _doneness())
	if _over > 0:
		for i in 3:
			_px(OVEN_MOUTH.x - 4 + i * 3, OVEN_MOUTH.y + 2 + int((1.0 - _over) * 6), 2, 2, Color(0.2, 0.18, 0.16, 0.7))


## A round pie seen from above at `x`, `y`, `d` = how browned: crust with a lattice, filling between.
func _draw_pie(x: float, y: float, d: float, size_k: float) -> void:
	var crust := C_DOUGH.lerp(C_CRUST, d)
	var r := roundf(6.0 * size_k)
	_ellipse(x + 1, y + 1, r, r, Color(0, 0, 0, 0.3))
	_ellipse(x, y, r + 1, r + 1, C_OUT)
	_ellipse(x, y, r, r, crust.darkened(0.1))
	_ellipse(x, y, r - 2, r - 2, dish_color if dish_color.get_luminance() < 0.45 else dish_color.darkened(0.3))
	# Lattice strips.
	for k in range(-int(r) + 2, int(r) - 1, 3):
		var hw := floorf(sqrt(maxf(0.0, (r - 2) * (r - 2) - k * k)))
		_px(x - hw, y + k, hw * 2 + 1, 1, crust)
		_px(x + k, y - hw, 1, hw * 2 + 1, crust)
	_px(x - r + 2, y - 2, 1, 2, crust.lightened(0.2))
	_px(x - 2, y - r + 1, 2, 1, crust.lightened(0.2))


func _draw_thermo() -> void:
	var r := THERMO
	var zone: Vector2 = _zone
	_px(r.position.x, r.position.y + 1, r.size.x + 3, r.size.y + 7, Color(0, 0, 0, 0.3))
	_px(r.position.x - 1, r.position.y - 1, r.size.x + 2, r.size.y + 6, C_OUT)
	_px(r.position.x, r.position.y, r.size.x, r.size.y, Color("2a1c12"))
	var zy0 := r.end.y - r.size.y * zone.y
	var zy1 := r.end.y - r.size.y * zone.x
	_px(r.position.x, zy0, r.size.x, zy1 - zy0, C_GREEN.darkened(0.45))
	# The best heat: a lighter band in the middle of the zone (quality).
	var sweet := float(GameData.QUALITY["sweet"])
	var sy0 := roundf(r.end.y - r.size.y * (quality.centre() + sweet))
	var sy1 := roundf(r.end.y - r.size.y * (quality.centre() - sweet))
	_px(r.position.x, sy0, r.size.x, sy1 - sy0, C_GREEN.darkened(0.2))
	_px(r.position.x - 2, roundf((sy0 + sy1) / 2.0), 1, 1, C_GREEN.lightened(0.3))
	_px(r.position.x, r.position.y, r.size.x, 4, C_RED.darkened(0.4))
	var shown := _temp if step >= Step.COOK else 0.0
	var hgt := floorf(r.size.y * clampf(shown, 0.0, 1.0))
	var in_zone := shown >= zone.x and shown <= zone.y
	var col := C_GREEN if in_zone else (C_RED if shown > zone.y else Color("d0c0a0"))
	_px(r.position.x + 1, r.end.y - hgt, r.size.x - 2, hgt, col)
	_ellipse(r.get_center().x, r.end.y + 2, 3, 2, col)
	if in_zone and step == Step.COOK:
		_ellipse(r.get_center().x, r.end.y + 2, 5, 4, Color(C_GREEN, 0.2 + 0.15 * sin(_t * 8)))
	for i in 5:
		_px(r.end.x + 1, r.position.y + i * r.size.y / 4.0, 2, 1, C_STONE4)


## A kitchen knife seen from above, blade up, at `p` (top of the blade); `lifted` draws it higher with a shadow.
func _knife_at(p: Vector2, lifted: bool) -> void:
	var q := p
	if lifted:
		_px(p.x + 1, p.y + 2, 2, 13, Color(0, 0, 0, 0.3))
		q = p + Vector2(-1, -3)
	_px(q.x - 1, q.y - 1, 4, 10, C_OUT)
	_px(q.x, q.y, 2, 8, C_STONE1)
	_px(q.x + 1, q.y + 1, 1, 7, C_STONE3)
	_px(q.x - 1, q.y + 8, 4, 6, C_OUT)
	_px(q.x, q.y + 9, 2, 4, C_TABLE_TOP)
	_px(q.x, q.y + 9, 1, 4, C_WOOD)


func _draw_plates() -> void:
	if _filled.size() < amount:
		return
	for i in amount:
		var hop := sin(float(_plate_hop[i]) * PI)
		var p: Vector2 = PLATES[i]
		var r := 6.0 + roundf(hop)
		if drink:
			# Clay mug seen from above: rim, handle, the drink inside.
			_shadow(p + Vector2(1, 2), 5, 4)
			_px(p.x + 4, p.y - 1, 3, 3, C_OUT)
			_px(p.x + 5, p.y, 1, 1, C_WOOD)
			_ellipse(p.x, p.y, r - 1, r - 1, C_OUT)
			_shaded(p, r - 2, [C_WOOD2, C_WOOD, C_WOOD3], r - 4)
			_ellipse(p.x, p.y, r - 4, r - 4, C_WOOD3.darkened(0.4) if not _filled[i] else dish_color)
			if _filled[i]:
				_px(p.x - 1, p.y - 1, 1, 1, dish_color.lightened(0.3))
		else:
			_shadow(p + Vector2(1, 2), r, r - 1)
			_ellipse(p.x, p.y, r + 1, r + 1, C_PLATE2.darkened(0.4))
			_ellipse(p.x, p.y, r, r, C_PLATE)
			_ring_free(p, r - 2, C_PLATE2)
			_px(p.x - 3, p.y - r + 1, 3, 1, Color(1, 1, 1, 0.6))
			if _filled[i]:
				_draw_portion(p.x, p.y)


## One portion seen from above, centred on `x`, `y`.
func _draw_portion(x: float, y: float) -> void:
	match method:
		"bake":
			_draw_pie(x, y, 1.0, 0.6)
		"fry":
			_ellipse(x, y, 5, 3, C_OUT)
			_ellipse(x, y, 4, 2, dish_color)
			_px(x - 2, y - 1, 2, 1, dish_color.lightened(0.2))
			_px(x + 3, y + 2, 1, 1, C_GREEN)
			_px(x + 4, y + 1, 1, 1, C_GREEN.darkened(0.2))
		_:
			# A wooden bowl of soup on the plate.
			_ellipse(x, y, 4, 4, C_OUT)
			_ellipse(x, y, 3, 3, C_WOOD3)
			_ellipse(x, y, 2, 2, dish_color)
			_px(x - 1, y - 1, 1, 1, dish_color.lightened(0.3))


func _draw_transfer() -> void:
	if _transfer <= 0:
		return
	var t := 1.0 - _transfer
	var dough_move := method == "bake" and _dough_in_oven and step >= Step.COOK
	for i in (1 if dough_move else 6):
		var k := clampf(t * 1.3 - i * 0.06, 0.0, 1.0)
		var lift := sin(k * PI)
		var p := _transfer_from.lerp(_transfer_to, k)
		if dough_move:
			_shadow(p + Vector2(2, 3) * (1.0 + lift), 5, 4)
			var r := 5.0 + roundf(lift * 2)
			p.y -= lift * 3
			_ellipse(p.x, p.y, r + 1, r + 1, C_OUT)
			_ellipse(p.x, p.y, r, r, C_DOUGH)
		elif k > 0 and k < 1:
			p += Vector2(i % 3 - 1, i / 3.0 - 0.5) * 2
			var s := 1.0 + roundf(lift)
			_px(p.x + 2, p.y + 2 + lift * 3, 1, 1, Color(0, 0, 0, 0.25))
			_px(p.x, p.y - lift * 2, s, s, _transfer_col.lightened(0.2))


## The portion flying from the pot / pan / oven to a plate (lifted towards the camera, a wisp of steam behind).
func _draw_serving() -> void:
	if _serve_to == -1:
		return
	var from := POT
	if method == "fry":
		from = PAN
	elif method == "bake":
		from = PIE_AT
	var to: Vector2 = PLATES[_serve_to]
	var k := clampf(_serve_t, 0.0, 1.0)
	var lift := sin(k * PI)
	var p := from.lerp(to, k)
	_shadow(p + Vector2(2, 3) * (1.0 + lift), 4, 3)
	for j in 3:
		var kk := maxf(0.0, k - 0.08 * (j + 1))
		var q := from.lerp(to, kk) + Vector2(0, -2)
		_px(q.x, q.y, 1, 1, Color(0.85, 0.82, 0.78, 0.35 - j * 0.1))
	p.y -= lift * 3
	if drink or method == "boil":
		var r := 3.0 + roundf(lift)
		_ellipse(p.x, p.y, r + 1, r + 1, C_OUT)
		_ellipse(p.x, p.y, r, r, C_STONE3)
		_ellipse(p.x, p.y, r - 1, r - 1, dish_color.lightened(0.1))
	elif method == "bake":
		_draw_pie(p.x, p.y, 1.0, 0.6 + 0.15 * lift)
	else:
		_ellipse(p.x, p.y, 5 + roundf(lift), 3 + roundf(lift), C_OUT)
		_ellipse(p.x, p.y, 4 + roundf(lift), 2 + roundf(lift), dish_color)


## A round wicker basket with the ingredients in it.
func _draw_basket() -> void:
	var c := BASKET
	var r := BASKET_RX
	_ellipse(c.x + 2, c.y + 3, r.x, r.y - 1, Color(0, 0, 0, 0.3))
	_ellipse(c.x, c.y, r.x + 1, r.y + 1, C_OUT)
	_ellipse(c.x, c.y, r.x, r.y, C_WICKER.darkened(0.25))
	# The plaited rim, lit on the top left: rows of woven strands going round.
	for ring in 3:
		var rr := r - Vector2(ring, ring)
		var n := int(rr.x * 3.2)
		for i in n:
			var a := i * TAU / n
			var d := Vector2(cos(a), sin(a))
			var lit := d.dot(LIGHT)
			var shade := C_WICKER.lightened(0.25) if lit > 0.2 else (C_WICKER if lit > -0.4 else C_WICKER.darkened(0.4))
			if (i + ring) % 3 == 0:
				shade = shade.darkened(0.35)
			_px(roundf(c.x + d.x * rr.x), roundf(c.y + d.y * rr.y), 1, 1, shade)
	_ellipse(c.x, c.y, r.x - 3, r.y - 3, Color("3a2814"))
	# A cloth on the bottom.
	_ellipse(c.x, c.y, r.x - 4, r.y - 4, Color("8a7a5a"))
	_ellipse(c.x + 1, c.y + 1, r.x - 6, r.y - 6, Color("7a6a4c"))
	for i in 7:
		_px(c.x - 14 + i * 4, c.y - 8 + (i * 5) % 15, 3, 1, Color("6a5a40"))


## True if the point is over the basket (`grow` widens the oval).
func _in_basket(p: Vector2, grow: float = 1.0) -> bool:
	var d := (p - BASKET) / (BASKET_RX + Vector2(grow, grow))
	return d.length_squared() <= 1.0


## The waste bucket: a wooden pail seen from above; it hops when something lands in it.
func _draw_bin() -> void:
	var c := BIN + Vector2(0, -roundf(_bin_hop))
	_ellipse(BIN.x + 2, BIN.y + 3, BIN_R, BIN_R - 1, Color(0, 0, 0, 0.3))
	_ellipse(c.x, c.y, BIN_R + 1, BIN_R + 1, C_OUT)
	_shaded(c, BIN_R, [C_WOOD2, C_WOOD, C_TABLE_TOP, C_TABLE], BIN_R - 2)
	for i in 8:
		var a := i * TAU / 8.0 + 0.3
		var p := c + Vector2(cos(a), sin(a)) * (BIN_R - 1)
		_px(roundf(p.x), roundf(p.y), 1, 1, C_OUT)
	_ellipse(c.x, c.y, BIN_R - 2, BIN_R - 2, Color("160c06"))
	# What was thrown in.
	for i in mini(_binned, 6):
		var p := c + Vector2(((i * 5) % 9) - 4, ((i * 7) % 8) - 4)
		_px(p.x, p.y, 3, 1, Color("5a6a34") if i % 2 == 0 else Color("6a5a40"))
	# The iron handle lying across.
	_line(c + Vector2(-BIN_R, 0), c + Vector2(-3, -BIN_R + 3), C_IRON3, 1)


## A soft light under a tool that is needed now or is under the mouse.
func _glow_rest(tool: String, r: Rect2) -> void:
	var wanted := _wanted_tool() == tool
	var hover := not _pressed and _held == -1 and _tool_rest_at(_mouse) == tool
	if wanted or hover:
		var a := 0.22 + (0.12 * sin(_t * 5) if wanted else 0.0)
		_px(r.position.x - 1, r.position.y - 1, r.size.x + 2, r.size.y + 2, Color(1.0, 0.85, 0.4, a))


func _saucer_at(c: Vector2, lifted: bool) -> void:
	var r := SAUCER_R + (1.0 if lifted else 0.0)
	if lifted:
		_shadow(c + Vector2(3, 5), r, r - 1)
	else:
		_ellipse(c.x + 1, c.y + 2, r, r - 1, Color(0, 0, 0, 0.3))
	_ellipse(c.x, c.y, r + 1, r + 1, C_OUT)
	_shaded(c, r, [Color("e8dcc4"), Color("cfc0a4"), Color("a89878"), Color("86775c")], r - 2)
	_ellipse(c.x, c.y, r - 2, r - 2, Color("b8a888"))
	_ellipse(c.x + 1, c.y + 1, r - 3, r - 3, Color("c8b898"))


## Bellows seen from above: the nozzle points along `dir`, `squeeze` 0..1 flattens the leather bag.
func _bellows_at(c: Vector2, dir: Vector2, squeeze: float) -> void:
	var side := dir.orthogonal()
	var half := 5.0 - 2.0 * squeeze
	var back := c - dir * 7
	var front := c + dir * 4
	for i in 12:
		var k := i / 11.0
		var p := back.lerp(front, k)
		var w := half * (1.0 - 0.75 * k * k)
		_line(p - side * (w + 1), p + side * (w + 1), C_OUT, 1)
	for i in 12:
		var k := i / 11.0
		var p := back.lerp(front, k)
		var w := half * (1.0 - 0.75 * k * k)
		_line(p - side * w, p + side * w, C_LEATHER if i % 3 else C_LEATHER.darkened(0.3), 1)
		_px(roundf(p.x - side.x * w * 0.5), roundf(p.y - side.y * w * 0.5), 1, 1, C_LEATHER.lightened(0.2))
	# Wooden handles at the back, the iron nozzle at the front.
	_line(back - dir * 4 - side * 2, back - side * 2, C_OUT, 3)
	_line(back - dir * 4 + side * 2, back + side * 2, C_OUT, 3)
	_line(back - dir * 4 - side * 2, back - side * 2, C_WOOD2, 1)
	_line(back - dir * 4 + side * 2, back + side * 2, C_WOOD2, 1)
	_line(front, front + dir * 5, C_OUT, 3)
	_line(front, front + dir * 5, C_STONE2, 1)


## Where a thing is drawn now (it slides to its place after a drop).
func _shown_pos(i: int) -> Vector2:
	var pos: Vector2 = _objs[i]["pos"]
	for f in _flights:
		if int(f["i"]) == i:
			var k := float(f["t"])
			return (Vector2(f["from"]).lerp(pos, k) + Vector2(0, -sin(k * PI) * 4)).round()
	return pos


## The icon cut at `cuts` (x positions 0..ICON), the slices drawn `gap` apart. `dose` < 1 leaves fewer slices.
func _draw_slices(tex: Texture2D, pos: Vector2, cuts: Array, gap: float, dose: float = 1.0) -> void:
	var xs := [0.0]
	var sorted := cuts.duplicate()
	sorted.sort()
	xs.append_array(sorted)
	xs.append(ICON)
	var src := Vector2(tex.get_width(), tex.get_height())
	var parts := xs.size() - 1
	var shown := maxi(1, ceili(parts * dose)) if dose > 0.0 else 0
	var base := pos - Vector2(ICON, ICON) / 2.0 - Vector2(gap * (parts - 1) / 2.0, 0)
	for k in shown:
		var x0 := float(xs[k])
		var w := float(xs[k + 1]) - x0
		var jump := 1.0 if k == sorted.size() and _hop > 0.3 and gap < 1.0 else 0.0
		draw_texture_rect_region(tex, Rect2(base + Vector2(x0 + k * gap, -jump), Vector2(w, ICON)), Rect2(src.x * x0 / ICON, 0, src.x * w / ICON, src.y))
