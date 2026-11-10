extends Control
## Interactive brewing, drawn in the 320x180 pixel style of the tavern, seen from above. Since 2026-11-09 the
## ingredients are real things on the alchemy table that the keeper handles himself:
## 1) PREP: take ingredients out of the basket (drag) and put them anywhere on the table, on the cutting board or
##    in the mortar. Tools are picked up with a click and stay in the hand (right click / click elsewhere puts them
##    back): the knife cuts where you click (even slices = quality), the pestle cracks, presses and grinds.
##    Some ingredients have a move of their own: herbs are plucked first (three clicks, the stem is waste for the
##    bucket), bones and crystals are cracked before grinding, the toad hops away, pouches and the wisp jar are
##    shaken out over the cauldron by hand. Prepared things are carried to the cauldron by hand or kept in the
##    saucers and tipped in later (as much as you like: the dose is part of the quality);
## 2) STIR: take the spoon, hold and circle it in the cauldron;
## 3) HEAT: take the bellows, hold the button to fan the fire, keep the needle in the green zone;
## 4) COOL: waits by itself, clicks blow on it;
## 5) POUR: put an empty flask from the rack on the stand, scoop with the ladle (click the cauldron, click the
##    flask), then push a cork in.
## Nothing is spent here: when the cork is in, the station emits `finished` and main.gd calls GameState.brew().

signal finished
signal step_changed(step: int)
## A short hint for the label under the title ("" = the step's normal hint).
signal message(text: String)
## An experiment: how many ingredients are in the cauldron now (main.gd shows the "enough, stir" button).
signal added_changed(count: int)

const GameData := preload("res://scripts/game_data.gd")
const CraftQuality := preload("res://scripts/craft_quality.gd")

enum Step { PREP, STIR, HEAT, COOL, POUR, DONE }

const W := 200
const H := 104
const TITLES := ["Підготуй інгредієнти", "Розмішай ложкою", "Розігрій міхом", "Дай схолонути", "Розлий у пляшечку"]
const HINTS := [
	"Перетягуй інгредієнти з кошика на стіл, дошку чи в ступку. Ніж і товкачик береш клацанням (правий клац кладе назад). Готове неси в казан або пересип у блюдце. Коли все в казані, бери ложку.",
	"Клацни по ложці, щоб узяти її, затисни кнопку й покрути в казані по колу: три оберти.",
	"Клацни по міху, щоб узяти його, і тримай кнопку миші: він роздмухує вогонь. Тримай стрілку в зеленій зоні. Перегрієш, і зілля википить через край.",
	"Зілля холоне саме. Клацай по ньому, щоб подути й прискорити.",
	"Перетягни порожню пляшечку з полички на підставку. Візьми черпак: клац по казану набирає, клац по пляшечці наливає. Наприкінці перетягни корок.",
	"Готово!",
]
## What to do with an ingredient, by its preparation (GameData.BREW_PREP).
const ACT_WHERE := {"grind": "розітри у ступці", "chop": "наріж на дошці", "squeeze": "розчави у ступці", "sprinkle": "потруси над казаном"}
const TOOL_NAMES := {"knife": "ніж", "pestle": "товкачик", "spoon": "ложку", "bellows": "міх", "ladle": "черпак"}

## How much rubbing (logical pixels of mouse travel) turns one ingredient into powder.
const GRIND_DISTANCE := 75.0
const CHOP_CUTS := 3
const SQUEEZES := 3
const CRACKS := 3
const PLUCKS := 3
const SPRINKLE_DISTANCE := 90.0
const STIR_TURNS := 3.0
const HEAT_RISE := 0.42
const HEAT_FALL := 0.22
const HEAT_ZONE := Vector2(0.58, 0.84)
const HEAT_SECONDS := 2.2
const COOL_SECONDS := 4.0
const BLOW := 0.1
const SCOOPS := 2
## Seconds a saucer takes to tip everything into the cauldron.
const TIP_SECONDS := 0.7
const FLY := 0.16
const ICON := 16.0
const CORK_TIME := 0.18
## Seconds between the toad's hops on the table; on the board it jumps off after TOAD_BOARD s without a cut.
const TOAD_HOP := 1.1
const TOAD_BOARD := 2.6

# Palette taken from the tavern background.
const C_SEAM := Color("0b0503")
const C_TABLE_TOP := Color("6e4e30")
const C_TABLE := Color("3d2614")
const C_TABLE_DARK := Color("25150b")
const C_OUT := Color("1a0f0a")
const C_WOOD := Color("9a7248")
const C_WOOD2 := Color("c49a64")
const C_STONE1 := Color("b4a894")
const C_STONE2 := Color("968a78")
const C_STONE3 := Color("7a6f60")
const C_STONE4 := Color("5e554a")
const C_STONE5 := Color("443c34")
const C_IRON := Color("2a221c")
const C_IRON2 := Color("443c34")
const C_IRON3 := Color("5e554a")
const C_WATER := Color("4a7ab0")
const C_FIRE := [Color("fff0a0"), Color("f2c14e"), Color("ff8a2a"), Color("c83a1a")]
const C_GREEN := Color("7ab04e")
const C_RED := Color("c83a1a")
const C_WICKER := Color("b08a4e")
const C_LEATHER := Color("6a3a24")
## Direction the light comes from (top left), for shading round things.
const LIGHT := Vector2(-0.6, -0.8)

# Layout (logical pixels).
const BASKET := Vector2(25, 20)
## Half-width and half-height of the oval basket.
const BASKET_RX := Vector2(22, 17)
const BIN := Vector2(86, 15)
const BIN_R := 9.0
const BOARD := Vector2(30, 62)         # centre of the cutting board (26 x 16)
const KNIFE_REST := Vector2(50, 54)    # top of the blade when the knife lies by the board
const MORTAR := Vector2(74, 64)
const MORTAR_R := 12.0
const SAUCERS := [Vector2(10, 92), Vector2(27, 92), Vector2(44, 92), Vector2(61, 92)]
const SAUCER_R := 7.0
const CAULDRON := Vector2(128, 44)
const LIQ_R := 13.0
const POT_R := 18.0
const HEARTH_R := 26.0
const THERMO := Rect2(162, 18, 5, 38)
const SPOON_REST := Rect2(98, 80, 24, 9)
const BELLOWS_REST := Rect2(125, 78, 20, 13)
const LADLE_REST := Rect2(148, 79, 22, 11)
const RACK := Rect2(173, 5, 25, 17)
const STAND := Vector2(185, 44)        # where the flask is filled
const CORKS := Vector2(185, 76)
const TABLE_AREA := Rect2(2, 2, 97, 78)
## Where the things lie in the basket (centres, relative to BASKET).
const BASKET_SPOTS := [Vector2(-11, -3), Vector2(11, -3), Vector2(0, 6), Vector2(0, -8), Vector2(-11, 7),
	Vector2(11, 7), Vector2(-16, 1), Vector2(16, 1), Vector2(-5, -1), Vector2(6, -1)]
const READY := ["slices", "powder", "pulp"]
## Top-down sprites of the ingredients, one 16x16 cell each in this order (tools/icons/gen_table_sprites.py ORDER).
const TABLE_SHEET := preload("res://assets/objects/table_ingredients.png")
const TABLE_SPRITES := ["herbs", "bones", "crystal", "burdock", "mandrake", "glow_mushroom", "berries", "grave_dust",
	"ether_essence", "swamp_moss", "lake_weed", "toad", "nightshade", "wisp_jar", "chicken", "bread",
	"perch", "pike", "crayfish", "spices"]

var potion_id := ""
## An experiment: the basket holds what is in storage, the player puts in 2..EXPERIMENT_MAX pieces and main.gd
## tells the outcome (set_outcome) when the stirring starts. potion_id is "" until then.
var experiment := false
## Quality measurements of this brew (order, heat precision, boil-overs, handiwork).
var quality := CraftQuality.new()
var step: int = Step.PREP
var potion_color := Color("9a4ac8")
var herb_color := Color("4f8a3a")

## Things on the table: {"id", "kind": raw | leaves | slices | powder | pulp | waste, "where": basket | table | board |
## mortar | saucer | hand | gone, "pos": centre, "slot": saucer, "dose": what is left of it 0..1, "ing": a recipe
## ingredient (not a by-product), "counted": some of it is in the cauldron, "act", "col", "tex", "work", "hits",
## "cuts", "plucks", "t"}.
var _objs: Array = []
## Index of the thing carried in the hand (mouse button held), -1 = none; where it was taken from.
var _held := -1
var _origin := {}
## The tool in the hand (stays until put back): "", knife, pestle, spoon, bellows, ladle.
var _tool := ""
## "flask" / "cork" dragged in the POUR step.
var _carry := ""
var _flask_on := false
var _flask_taken := 0
var _scoops := 0
var _ladle_full := false
var _zone := HEAT_ZONE
var _cuts := CHOP_CUTS
var _grind := GRIND_DISTANCE
var _squeezes := SQUEEZES
var _added := 0
var _knife := 0.0
var _mix_start := C_WATER
var _stir := 0.0
var _stir_angle := 0.0
var _heat := 0.0
var _temp := 0.0
var _cool := 0.0
var _boil := 0.0
var _pressed := false
var _press_pos := Vector2.ZERO
var _press_t := 0.0
var _mouse := Vector2(-100, -100)
var _pestle := Vector2.ZERO
var _particles: Array = []
var _t := 0.0
var _sound_mark := 0
var _ripples: Array = []
var _bubbles: Array = []
## Things sliding to their place after a drop: {"i", "from", "t"}.
var _flights: Array = []
var _hop := 0.0
var _wobble := 0.0
var _stir_speed := 0.0
var _done_t := 0.0
var _binned := 0
var _bin_hop := 0.0

static var _color_cache := {}
static var _span_cache := {}


func _ready() -> void:
	custom_minimum_size = Vector2(W, H) * 3
	mouse_filter = Control.MOUSE_FILTER_STOP
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	set_process(false)


## Starts a new brew of this recipe. Colours come from GameData.RECIPES ("color", "herb").
func start(id: String, recipe: Dictionary) -> void:
	experiment = false
	potion_id = id
	potion_color = Color(String(recipe.get("color", "9a4ac8")))
	herb_color = Color(String(recipe.get("herb", "4f8a3a")))
	var pieces := GameData.recipe_order(id)
	_reset(pieces, pieces)


## An experiment: the basket holds up to 10 pieces of what is in storage ({item: count}, every kind once, then
## a second piece of each while there is room). The player puts in what they like.
func start_experiment(stock: Dictionary) -> void:
	experiment = true
	potion_id = ""
	potion_color = Color("7a6a5a")
	herb_color = Color("6e8a3a")
	var pieces := []
	for round_ in 2:
		for id in stock:
			if pieces.size() < BASKET_SPOTS.size() and int(stock[id]) > round_:
				pieces.append(id)
	pieces.sort_custom(func(a: String, b: String) -> bool: return a < b)
	_reset(pieces, [])


## The experiment's outcome is known (main.gd asked GameState): its colour and the recipe's order (for quality).
func set_outcome(id: String, color: Color, order: Array) -> void:
	potion_id = id
	potion_color = color
	quality.expected = order.duplicate()


## An experiment: stop adding ingredients and go on to stirring (needs EXPERIMENT_MIN of them).
func finish_prep() -> void:
	_try_stir(false)


## Ingredient ids in the order they went into the cauldron.
func added_ids() -> Array:
	return quality.added.duplicate()


func added_count() -> int:
	return _added


## Quality of the brew so far (GameData.QUALITY).
func current_quality() -> int:
	return quality.quality()


## Sets everything up for a new brew. basket: item ids to put into the basket (a known recipe: shuffled);
## order: the recipe's order ([] = unknown).
func _reset(basket: Array, order: Array) -> void:
	_zone = CraftQuality.widened(HEAT_ZONE)
	quality.reset(order, _zone)
	var prep := int(GameState.upgrade_value("tools", "prep"))
	_cuts = CHOP_CUTS - prep
	_squeezes = SQUEEZES - prep
	_grind = GRIND_DISTANCE * (1.0 - 0.25 * prep)
	step = Step.PREP
	_stir = 0.0
	_stir_angle = -PI / 2
	_heat = 0.0
	_temp = 0.0
	_cool = 0.0
	_boil = 0.0
	_pressed = false
	_sound_mark = 0
	_held = -1
	_origin = {}
	_tool = ""
	_carry = ""
	_flask_on = false
	_flask_taken = 0
	_scoops = 0
	_ladle_full = false
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
	_done_t = 0.0
	_pestle = MORTAR + Vector2(2, 1)
	_objs.clear()
	var shuffled := basket.duplicate()
	if not experiment and shuffled.size() > 1:
		# Never in the right order already: the order is the player's job.
		for attempt in 6:
			shuffled.shuffle()
			if shuffled != order:
				break
	for k in shuffled.size():
		var ing_id: String = shuffled[k]
		var o := _make_obj(ing_id, "raw", BASKET + BASKET_SPOTS[k % BASKET_SPOTS.size()])
		o["where"] = "basket"
		o["home"] = o["pos"]
		o["ing"] = true
		_objs.append(o)
	_mix_start = C_WATER
	set_process(true)
	step_changed.emit(step)
	queue_redraw()


func _make_obj(id: String, kind: String, pos: Vector2) -> Dictionary:
	var real := GameData.ITEMS.has(id)
	return {
		"id": id, "kind": kind, "where": "table", "pos": pos, "home": pos, "slot": -1, "dose": 1.0, "ing": false,
		"counted": false, "act": String(GameData.BREW_PREP.get(id, "grind")) if real else "",
		"col": _icon_color(id) if real else Color("5a6a34"), "tex": table_texture(id) if real else null,
		"work": 0.0, "hits": 0, "cuts": [], "cut_score": 1.0, "plucks": 0, "t": 0.0, "seed": randi() % 1000,
	}


func stop() -> void:
	set_process(false)
	_pressed = false
	_held = -1
	_tool = ""
	_carry = ""


## 0..1 progress of the current step (for the bar under the scene).
func progress() -> float:
	match step:
		Step.PREP:
			var total := 0
			for o in _objs:
				if o["ing"]:
					total += 1
			if experiment:
				total = GameData.EXPERIMENT_MAX
			return minf(1.0, _added / maxf(1.0, total))
		Step.STIR:
			return _stir
		Step.HEAT:
			return _heat
		Step.COOL:
			return _cool
		Step.POUR:
			return (float(_scoops) + (0.5 if _flask_on else 0.0)) / (SCOOPS + 0.5)
	return 1.0


func _name(o: Dictionary) -> String:
	var id: String = o["id"]
	if not GameData.ITEMS.has(id):
		return "Стебла"
	return String(GameData.ITEMS[id]["name"])


func _say(text: String) -> void:
	message.emit(text)


# ---------- Where things are ----------

## What is under the point: saucerN, basket, bin, board, mortar, cauldron, stand, rack, corks, table or "".
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
	if p.distance_to(MORTAR) < MORTAR_R + 2:
		return "mortar"
	if p.distance_to(CAULDRON) < POT_R + 2:
		return "cauldron"
	if p.distance_to(STAND) < 11:
		return "stand"
	if RACK.grow(2).has_point(p):
		return "rack"
	if p.distance_to(CORKS) < 9:
		return "corks"
	if TABLE_AREA.has_point(p):
		return "table"
	return ""


## The tool lying at the point (not the one in the hand): knife, pestle, spoon, bellows, ladle or "".
func _tool_rest_at(p: Vector2) -> String:
	if _tool != "knife" and Rect2(KNIFE_REST.x - 3, KNIFE_REST.y - 2, 8, 18).has_point(p):
		return "knife"
	if _tool != "pestle" and p.distance_to(MORTAR + Vector2(10, -10)) < 5.5:
		return "pestle"
	if _tool != "spoon" and SPOON_REST.has_point(p):
		return "spoon"
	if _tool != "bellows" and BELLOWS_REST.has_point(p):
		return "bellows"
	if _tool != "ladle" and LADLE_REST.has_point(p):
		return "ladle"
	return ""


## Index of the thing lying in this place ("board", "mortar"), -1 = it is free.
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
			"mortar":
				if p.distance_to(MORTAR) < 8:
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


## True if this thing is carried together with its saucer.
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
		elif _tool == "spoon" and step == Step.STIR and p.distance_to(CAULDRON) < 26:
			_stir_angle = (p - CAULDRON).angle()
		_mouse = p


func _take_tool(tool: String) -> void:
	if _tool != "":
		_drop_tool()
	_tool = tool
	_ladle_full = false
	Audio.play("click")
	match tool:
		"knife":
			_say("Ніж у руці. Клацай по інгредієнту на дошці там, де різати: %d надрізи, якомога рівніше." % _cuts)
		"pestle":
			_say("Товкачик у руці. У ступці: клацай, щоб розколоти чи розчавити, затисни й три, щоб розтерти.")
		"spoon":
			_say("Ложка в руці. Затисни кнопку в казані й мішай по колу.")
		"bellows":
			_say("Міх біля вогню. Тримай кнопку миші, щоб дмухати. Світла смужка посеред зеленої зони: найкраща якість.")
		"ladle":
			_say("Черпак у руці. Клац по казану набирає, клац по пляшечці наливає.")


## Puts the tool in the hand back to its place.
func _drop_tool() -> void:
	if _tool == "":
		return
	_tool = ""
	_ladle_full = false
	Audio.play("shelf")


func _on_press() -> void:
	match step:
		Step.PREP:
			_press_prep()
		Step.STIR:
			if _tool != "spoon":
				if _tool_rest_at(_mouse) == "spoon":
					_take_tool("spoon")
				else:
					_say("Мішають ложкою: клацни по ній, вона лежить під казаном.")
		Step.HEAT:
			if _tool != "bellows":
				if _tool_rest_at(_mouse) == "bellows":
					_take_tool("bellows")
				else:
					_say("Вогонь роздмухують міхом: клацни по ньому, він лежить під казаном.")
		Step.COOL:
			_cool = minf(1.0, _cool + BLOW)
			Audio.play("page")
			_ripple(CAULDRON + Vector2(-6, randf_range(-4, 4)), liquid_color())
			for p in _particles:
				if p.has("steam"):
					p["v"] = Vector2(p["v"]) + Vector2(randf_range(18, 30), 0)
			for i in 4:
				_particles.append({"p": CAULDRON + Vector2(-POT_R - 6, -3 + i * 2), "v": Vector2(randf_range(28, 40), randf_range(-4, 4)), "life": 0.5, "l0": 0.5, "c": Color(0.9, 0.9, 1.0, 0.6), "air": true})
			if _cool >= 1.0:
				_next()
		Step.POUR:
			_press_pour()


func _press_prep() -> void:
	var rest := _tool_rest_at(_mouse)
	if rest == "spoon":
		_try_stir(true)
		return
	if rest == "bellows" or rest == "ladle":
		_say("Це знадобиться пізніше: спершу інгредієнти.")
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
	elif _tool == "pestle":
		if zone == "mortar":
			_pestle_press()
			return
		_drop_tool()
	var i := _obj_at(_mouse)
	if i != -1:
		_hold(i)


func _hold(i: int) -> void:
	var o: Dictionary = _objs[i]
	_held = i
	_origin = {"where": o["where"], "pos": o["pos"], "slot": o["slot"]}
	o["where"] = "hand"
	_sound_mark = 0
	Audio.play("click")
	_say(_hint_for(o))


## What to do with the thing just picked up.
func _hint_for(o: Dictionary) -> String:
	var id: String = o["id"]
	match String(o["kind"]):
		"waste":
			return "%s: відходи. Викинь у відро біля кошика." % ("Стебла" if id == "_stem" else "Порожнє")
		"leaves":
			return "Листя: поклади в ступку й розітри товкачиком."
		"slices", "powder", "pulp":
			return "Готово: неси в казан або поклади в блюдце на потім. З блюдця можна всипати й частину."
	if id in GameData.BREW_PLUCK:
		return "%s: поклади на стіл і клацни по ній %d рази, щоб обірвати листя. Тоді листя в ступку." % [_name(o), PLUCKS]
	if id in GameData.BREW_RUNAWAY:
		return "%s: клади на дошку й ріж швидко, бо втече!" % _name(o)
	if id in GameData.BREW_CRACK:
		return "%s: у ступку. Спершу розколи товкачиком (клацай), тоді розітри." % _name(o)
	return "%s: %s." % [_name(o), ACT_WHERE.get(o["act"], "")]


func _on_release() -> void:
	if step == Step.POUR:
		_release_pour()
		return
	if _held == -1:
		return
	var i := _held
	var o: Dictionary = _objs[i]
	var click := _mouse.distance_to(_press_pos) < 2.0 and _t - _press_t < 0.4
	if click:
		_back(o, false)
		_held = -1
		if o["kind"] == "raw" and String(o["id"]) in GameData.BREW_PLUCK and o["where"] == "table":
			_pluck(i)
		return
	_drop(o, _zone_at(_mouse))
	_held = -1


## Puts the carried thing back where it was taken from.
func _back(o: Dictionary, fly: bool = true) -> void:
	var where: String = _origin.get("where", "table")
	var pos: Vector2 = _origin.get("pos", o["pos"])
	if where == "basket" and (o["kind"] != "raw" or float(o["dose"]) < 1.0):
		# Something used does not go back into the basket: it stays on the table next to it.
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
		# A saucer always goes back to its place; what was tipped out is in the cauldron already.
		_back(o)
		Audio.play("shelf")
		return
	if zone.begins_with("saucer"):
		var slot := int(zone.substr(6))
		if not kind in READY:
			_refuse(o, "У блюдця кладуть уже нарізане чи розтерте.")
		elif _on("saucer", slot) != -1:
			_refuse(o, "Це блюдце зайняте.")
		else:
			_place(o, "saucer", SAUCERS[slot], slot)
			Audio.play("shelf")
			_say("У блюдці. Коли треба, перетягни блюдце над казан: воно висипається, поки тримаєш.")
		return
	match zone:
		"bin":
			if kind == "waste" or experiment:
				o["where"] = "gone"
				_binned += 1
				_bin_hop = 1.0
				Audio.play("shelf")
				_say("" if kind == "waste" else "Викинуто. В експерименті це нічого не коштує.")
			else:
				_refuse(o, "Це ще знадобиться. У відро йдуть лише відходи: стебла, порожні торбинки.")
		"basket":
			if kind == "raw" and float(o["dose"]) >= 1.0 and float(o["work"]) <= 0.0 and (o["cuts"] as Array).is_empty() and int(o["plucks"]) == 0:
				_place(o, "basket", o["home"])
			else:
				_back(o)
		"table":
			if kind in READY:
				_refuse(o, "Нарізане й розтерте на стіл не кладуть: у блюдце або просто в казан.")
			else:
				_place(o, "table", _mouse.clamp(TABLE_AREA.position + Vector2(7, 7), TABLE_AREA.end - Vector2(7, 7)))
				Audio.play("shelf")
				if kind == "raw" and id in GameData.BREW_PLUCK:
					_say("Клацни по траві %d рази, щоб обірвати листя." % PLUCKS)
		"board":
			if kind == "raw" and act == "chop" and _on("board") == -1:
				_place(o, "board", BOARD)
				Audio.play("shelf")
				_say("На дошці. Візьми ніж (клацни по ньому) і зроби %d надрізи. Що рівніші скибочки, то краща якість." % _cuts)
			elif kind == "raw" and act == "chop":
				_refuse(o, "Дошка зайнята: спершу прибери з неї нарізане.")
			else:
				_refuse(o, "На дошці це не ріжуть. %s" % _hint_for(o))
		"mortar":
			if _on("mortar") != -1:
				_refuse(o, "Ступка зайнята: спершу забери з неї готове.")
			elif kind == "raw" and id in GameData.BREW_PLUCK:
				_refuse(o, "Зі стеблами в ступку не можна. Поклади на стіл і клацни %d рази, щоб обірвати листя." % PLUCKS)
			elif kind == "leaves" or (kind == "raw" and (act == "grind" or act == "squeeze")):
				_place(o, "mortar", MORTAR)
				Audio.play("shelf")
				if kind == "raw" and id in GameData.BREW_CRACK:
					_say("У ступці. Візьми товкачик і розколи: %d удари (клацай). Потім розітри." % CRACKS)
				elif act == "squeeze":
					_say("У ступці. Візьми товкачик і розчави: клацни %d рази." % _squeezes)
				else:
					_say("У ступці. Візьми товкачик, затисни кнопку й три, поки не стане порошком.")
			else:
				_refuse(o, "У ступці цього не готують. %s" % _hint_for(o))
		"cauldron":
			if kind in READY:
				if not _enter(o, float(o["dose"])):
					_back(o)
			elif _sprinkled(o):
				if float(o["dose"]) >= 1.0:
					_say("Не кидай: затисни кнопку й потруси над казаном уліво-вправо.")
				_back(o)
			elif kind == "waste":
				_refuse(o, "Сміття в казан не кидають: відро стоїть біля кошика.")
			else:
				_refuse(o, "Сирим у казан не можна. %s" % _hint_for(o))
		_:
			_back(o)


## `amount` (0..1 of the whole thing) of `o` goes into the cauldron. False if the cauldron takes no more.
func _enter(o: Dictionary, amount: float) -> bool:
	if not o["counted"]:
		if experiment and _added >= GameData.EXPERIMENT_MAX:
			Audio.play("refuse")
			_say("У казані вже %d інгредієнтів: більше не влізе. Бери ложку." % GameData.EXPERIMENT_MAX)
			return false
		o["counted"] = true
		quality.added.append(o["id"])
		_added += 1
		Audio.play("brew")
		_splash(_on_liquid(3), o["col"], 5)
		if experiment:
			added_changed.emit(_added)
	amount = minf(amount, float(o["dose"]))
	o["dose"] = float(o["dose"]) - amount
	if float(o["dose"]) <= 0.001:
		o["dose"] = 0.0
		if _sprinkled(o):
			o["kind"] = "waste"
			_say("Порожньо. Торбинку чи банку викинь у відро.")
		else:
			o["where"] = "gone"
			_say("Усе в казані. Бери ложку (вона під казаном) і мішай." if _all_in() else "")
	return true


## True if every ingredient of the recipe is (at least partly) in the cauldron.
func _all_in() -> bool:
	if experiment:
		return _added >= GameData.EXPERIMENT_MIN
	for o in _objs:
		if o["ing"] and not o["counted"]:
			return false
	return true


## Goes on to stirring if everything is in the cauldron; `take` also picks the spoon up.
func _try_stir(take: bool) -> void:
	if step != Step.PREP or _held != -1:
		return
	if not _all_in():
		Audio.play("refuse")
		if experiment:
			_say("Замало: кинь у казан хоча б %d інгредієнти." % GameData.EXPERIMENT_MIN)
		else:
			_say("Ще не все в казані. Мішати рано.")
		return
	# The handiwork: full doses, even slices, a tidy table.
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
	_drop_tool()
	_next()
	if take:
		_take_tool("spoon")


func _pluck(i: int) -> void:
	var o: Dictionary = _objs[i]
	o["plucks"] = int(o["plucks"]) + 1
	_hop = 1.0
	Audio.play("gather")
	var pos: Vector2 = o["pos"]
	for k in 3:
		_particles.append({"p": pos + Vector2(randf_range(-3, 3), randf_range(-3, 3)), "v": _radial(8, 16), "life": 0.4, "l0": 0.4, "c": (o["col"] as Color).lightened(0.2), "drag": 5.0, "big": true})
	if int(o["plucks"]) >= PLUCKS:
		o["kind"] = "leaves"
		var stem := _make_obj("_stem", "waste", (pos + Vector2(9, 4)).clamp(TABLE_AREA.position + Vector2(7, 7), TABLE_AREA.end - Vector2(7, 7)))
		_objs.append(stem)
		_say("Листя обірвано. Листя в ступку, а стебла у відро: сміття на столі псує якість.")


## The knife comes down on the board where the mouse is.
func _cut() -> void:
	var i := _on("board")
	if i == -1 or _objs[i]["kind"] != "raw":
		_say("На дошці нічого різати: поклади туди корінь, гриб чи жабу.")
		return
	var o: Dictionary = _objs[i]
	var span := table_span(o["id"])
	var x := clampf(_mouse.x - (BOARD.x - ICON / 2.0), span.x + 0.5, span.y - 0.5)
	var cuts: Array = o["cuts"]
	for c in cuts:
		if absf(float(c) - x) < 1.2:
			_say("Тут уже надрізано. Клацни в іншому місці.")
			return
	cuts.append(x)
	o["t"] = 0.0
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
		_say(("Нарізано рівненько! " if float(o["cut_score"]) > 0.75 else "Нарізано, хоч і кривувато. ") + "Неси скибочки в казан або клади в блюдце.")


## A click with the pestle in the mortar: crack, press or the first rub.
func _pestle_press() -> void:
	var i := _on("mortar")
	if i == -1:
		_say("Ступка порожня: поклади в неї інгредієнт.")
		return
	var o: Dictionary = _objs[i]
	if o["kind"] in READY:
		_drop_tool()
		_hold(i)
		return
	_pestle = _clamp_to_mortar(_mouse)
	_wobble = 0.12
	if o["kind"] == "raw" and String(o["id"]) in GameData.BREW_CRACK and int(o["hits"]) < CRACKS:
		o["hits"] = int(o["hits"]) + 1
		Audio.play("dig")
		_knife = 0.12
		for k in 4:
			_particles.append({"p": MORTAR + Vector2(randf_range(-3, 3), randf_range(-3, 3)), "v": _radial(12, 24), "life": 0.4, "l0": 0.4, "c": (o["col"] as Color).lightened(0.3), "drag": 5.0, "big": true})
		if int(o["hits"]) >= CRACKS:
			_say("Розколото! Тепер затисни кнопку й розітри на порошок.")
		return
	if o["act"] == "squeeze":
		Audio.play("gather")
		for k in 4:
			_particles.append({"p": MORTAR + Vector2(randf_range(-3, 3), randf_range(-2, 3)), "v": _radial(4, 10), "life": randf_range(0.25, 0.45), "l0": 0.45, "c": (o["col"] as Color).darkened(0.1), "drag": 4.0})
		_work(o, 1.0 / _squeezes, "pulp")
		return
	_work(o, 6.0 / _grind, "powder")


func _work(o: Dictionary, amount: float, result: String) -> void:
	o["work"] = minf(1.0, float(o["work"]) + amount)
	if result == "powder":
		if randf() < 0.25:
			_particles.append({"p": _pestle + Vector2(randf_range(-2, 2), randf_range(-2, 2)), "v": _radial(8, 16), "life": 0.35, "l0": 0.35, "c": (o["col"] as Color).lightened(0.3), "drag": 5.0})
		var mark := int(float(o["work"]) * 4)
		if mark > _sound_mark:
			_sound_mark = mark
			Audio.play("dig" if o["id"] == "bones" else "gather")
	if float(o["work"]) >= 1.0:
		o["kind"] = result
		_sound_mark = 0
		_drop_tool()
		Audio.play("brew")
		_say("Готово! Неси в казан або пересип у блюдце.")


func _clamp_to_mortar(p: Vector2) -> Vector2:
	var d := p - MORTAR
	if d.length() > 6.0:
		d = d.normalized() * 6.0
	return MORTAR + d


func _on_drag(from: Vector2, to: Vector2) -> void:
	match step:
		Step.PREP:
			if _tool == "pestle" and to.distance_to(MORTAR) < MORTAR_R + 4:
				var i := _on("mortar")
				if i == -1:
					return
				var o: Dictionary = _objs[i]
				var tip := _clamp_to_mortar(to)
				var cracked: bool = not (String(o["id"]) in GameData.BREW_CRACK) or int(o["hits"]) >= CRACKS
				if (o["kind"] == "leaves" or (o["kind"] == "raw" and o["act"] == "grind")) and cracked:
					if tip.distance_to(_pestle) > 0.5:
						_wobble = 0.12
					_work(o, tip.distance_to(_pestle) / _grind, "powder")
				_pestle = tip
			elif _held != -1 and _sprinkled(_objs[_held]) and to.distance_to(CAULDRON) < POT_R + 2:
				var o: Dictionary = _objs[_held]
				var d := absf(to.x - from.x)
				if d > 0.0 and _enter(o, d / SPRINKLE_DISTANCE):
					if randf() < 0.6:
						var at := _clamp_to_liquid(to, LIQ_R - 3) + Vector2(randf_range(-3, 3), randf_range(-2, 2))
						_particles.append({"p": at, "v": _radial(1, 5), "life": randf_range(0.25, 0.45), "l0": 0.45, "c": (o["col"] as Color).lightened(0.2), "into": true, "star": o["id"] in ["ether_essence", "wisp_jar"] and randf() < 0.4})
					var mark := int((1.0 - float(o["dose"])) * 4)
					if mark > _sound_mark:
						_sound_mark = mark
						Audio.play("magic" if o["id"] in ["ether_essence", "wisp_jar"] else "gather")
		Step.STIR:
			if _tool == "spoon" and to.distance_to(CAULDRON) < 26 and from.distance_to(CAULDRON) < 26:
				var a := (to - CAULDRON).angle()
				var delta := wrapf(a - _stir_angle, -PI, PI)
				_stir_angle = a
				_stir_speed = minf(1.0, _stir_speed + absf(delta) * 0.6)
				_stir = minf(1.0, _stir + absf(delta) / (TAU * STIR_TURNS))
				var mark := int(_stir * STIR_TURNS * 2)
				if mark > _sound_mark:
					_sound_mark = mark
					Audio.play("gather")
				if _stir >= 1.0:
					_drop_tool()
					_next()


# ---------- Bottling ----------

func _press_pour() -> void:
	var zone := _zone_at(_mouse)
	if not _flask_on:
		if zone == "rack":
			_carry = "flask"
			Audio.play("click")
			_say("Постав пляшечку на шкіряну підставку під поличкою.")
		else:
			_say("Спершу перетягни порожню пляшечку з полички на підставку.")
		return
	if _scoops < SCOOPS:
		if _tool != "ladle":
			if _tool_rest_at(_mouse) == "ladle":
				_take_tool("ladle")
			else:
				_say("Наливають черпаком: клацни по ньому, він лежить під казаном.")
			return
		if zone == "cauldron":
			if not _ladle_full:
				_ladle_full = true
				Audio.play("splash")
				_ripple(_mouse, liquid_color())
				_say("Черпак повний. Тепер клацни по пляшечці.")
		elif zone == "stand":
			if _ladle_full:
				_ladle_full = false
				_scoops += 1
				Audio.play("pour")
				for k in 6:
					_particles.append({"p": STAND + Vector2(randf_range(-1, 1), randf_range(-1, 1)), "v": _radial(8, 14), "life": 0.25, "l0": 0.25, "c": potion_color.lightened(0.3), "drag": 6.0})
				if _scoops >= SCOOPS:
					_drop_tool()
					_say("Повна! Перетягни корок з мисочки внизу на пляшечку.")
				else:
					_say("Ще черпак: клац по казану, клац по пляшечці.")
			else:
				_say("Черпак порожній: спершу набери з казана.")
		return
	if zone == "corks":
		_carry = "cork"
		Audio.play("click")
	else:
		_say("Лишилося заткнути: перетягни корок з мисочки на пляшечку.")


func _release_pour() -> void:
	if _carry == "":
		return
	var zone := _zone_at(_mouse)
	if _carry == "flask" and zone == "stand":
		_flask_on = true
		_flask_taken = 1
		Audio.play("shelf")
		_say("Тепер черпак: клацни по ньому, потім по казану й по пляшечці.")
	elif _carry == "cork" and zone == "stand":
		step = Step.DONE
		_done_t = 0.0
		_carry = ""
		step_changed.emit(step)
		finished.emit()
		return
	_carry = ""


func _next() -> void:
	_sound_mark = 0
	_pressed = false
	match step:
		Step.PREP:
			_mix_start = liquid_color()
			message.emit("")
		Step.STIR, Step.HEAT:
			Audio.play("brew")
		Step.COOL:
			Audio.play("buy")
	step += 1
	step_changed.emit(step)


## True while the bellows blow into the fire.
func _pumping() -> bool:
	return step == Step.HEAT and _tool == "bellows" and _pressed and _boil <= 0


# ---------- Simulation ----------

func _process(delta: float) -> void:
	_t += delta
	_knife = maxf(0.0, _knife - delta)
	_hop = maxf(0.0, _hop - delta * 5)
	_bin_hop = maxf(0.0, _bin_hop - delta * 4)
	_wobble = maxf(0.0, _wobble - delta)
	_stir_speed = maxf(0.0, _stir_speed - delta * 1.5)
	for f in _flights:
		f["t"] = minf(1.0, float(f["t"]) + delta / FLY)
	_flights = _flights.filter(func(f: Dictionary) -> bool: return f["t"] < 1.0)
	if _boil > 0:
		_boil = maxf(0.0, _boil - delta)
	match step:
		Step.PREP:
			_update_prep(delta)
		Step.HEAT:
			if _boil > 0:
				_temp = maxf(0.3, _temp - HEAT_FALL * 3 * delta)
			elif _pumping():
				_temp += HEAT_RISE * delta
			else:
				_temp = maxf(0.0, _temp - HEAT_FALL * delta)
			if _temp >= 1.0:
				_temp = 1.0
				_boil = 1.0
				quality.boils += 1
				Audio.play("error")
				if quality.boils == GameData.SPOIL_BOILS - 1:
					message.emit("Википіло вже %d рази! Ще раз, і зілля зіпсується." % quality.boils)
				elif quality.boils >= GameData.SPOIL_BOILS:
					message.emit("Зілля зіпсувалося: вийде «%s». Можна доварити або скасувати." % GameData.ITEMS[GameData.SPOILED_POTION]["name"])
				else:
					message.emit("Википіло! Якість падає. Зачекай, поки охолоне.")
				for i in 12:
					var a := i * TAU / 12.0 + randf_range(-0.2, 0.2)
					var dir := Vector2(cos(a), sin(a))
					_particles.append({"p": CAULDRON + dir * (LIQ_R + 1), "v": dir * randf_range(14, 28), "life": 0.6, "l0": 0.6, "c": potion_color.lightened(0.2), "drag": 3.5, "big": true})
			elif _temp >= _zone.x and _temp <= _zone.y and _boil <= 0:
				quality.tick(delta, _temp)
				_heat = minf(1.0, _heat + delta / HEAT_SECONDS)
				if _heat >= 1.0:
					_drop_tool()
					_next()
		Step.COOL:
			_temp = maxf(0.0, _temp - delta * 0.2)
			_cool = minf(1.0, _cool + delta / COOL_SECONDS)
			if _cool >= 1.0:
				_next()
		Step.DONE:
			# The cork drops in, then a burst of sparkles (keeps animating until main.gd hides the station).
			var was := _done_t
			_done_t += delta
			if was < CORK_TIME and _done_t >= CORK_TIME:
				Audio.play("click")
				for k in 14:
					var a := k * TAU / 14.0 + randf_range(-0.2, 0.2)
					_particles.append({"p": STAND, "v": Vector2(cos(a), sin(a)) * randf_range(18, 34), "life": randf_range(0.4, 0.7), "c": potion_color.lightened(randf_range(0.2, 0.6)), "star": k % 3 == 0, "drag": 2.5})
			if randf() < delta * 5:
				_particles.append({"p": STAND + _radial(2, 9), "v": Vector2(0, -4), "life": 0.5, "c": potion_color.lightened(0.5), "star": true})
	# Steam over a hot pot (it rises towards the camera, swells and drifts off with the draught).
	var hot := _temp if step >= Step.HEAT else 0.0
	if step == Step.COOL:
		hot = 0.25 + 0.75 * (1.0 - _cool)
	if step >= Step.POUR:
		hot = 0.2
	if hot > 0.2 and randf() < hot * delta * 14:
		var life := randf_range(0.9, 1.5)
		_particles.append({"p": _on_liquid(), "v": Vector2(randf_range(3, 8), randf_range(-7, -3)), "life": life, "l0": life, "c": Color(0.85, 0.82, 0.78, 0.4), "steam": true, "sway": randf() * TAU})
	_update_fire_fx(delta, hot)
	_update_surface(delta, hot)
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
		# Drops and powder fall onto the liquid (shrinking away from the camera) and make a ring on it.
		if p.get("into", false) and float(p["life"]) <= 0.0 and pos.distance_to(CAULDRON) < LIQ_R and randf() < 0.6:
			_ripple(pos, liquid_color())
	_particles = _particles.filter(func(p: Dictionary) -> bool: return p["life"] > 0)
	queue_redraw()


## The table lives: a saucer held over the cauldron tips out, the toad hops away.
func _update_prep(delta: float) -> void:
	if _with_saucer() and _mouse.distance_to(CAULDRON) < POT_R + 2:
		var o: Dictionary = _objs[_held]
		if float(o["dose"]) > 0.0 and _enter(o, delta / TIP_SECONDS):
			if randf() < delta * 30:
				var at := _clamp_to_liquid(_mouse + Vector2(-3, 3), LIQ_R - 3)
				_particles.append({"p": at + Vector2(randf_range(-2, 2), randf_range(-2, 2)), "v": _radial(1, 5), "life": 0.35, "l0": 0.35, "c": (o["col"] as Color).lightened(0.15), "into": true})
	for i in _objs.size():
		var o: Dictionary = _objs[i]
		if o["kind"] != "raw" or not (String(o["id"]) in GameData.BREW_RUNAWAY) or not (o["cuts"] as Array).is_empty():
			continue
		var where: String = o["where"]
		if where != "table" and where != "board":
			continue
		o["t"] = float(o["t"]) + delta
		if where == "board" and float(o["t"]) > TOAD_BOARD:
			_place(o, "table", BOARD + Vector2(18, -16), -1, false)
			_flights.append({"i": i, "from": BOARD, "t": 0.0})
			Audio.play("expelled")
			_say("Жаба зіскочила з дошки! Лови її й ріж швидше.")
		elif where == "table" and float(o["t"]) > TOAD_HOP:
			var from: Vector2 = o["pos"]
			var to := from + Vector2(-9.0 if from.x < 50 else 9.0, randf_range(-5, 5))
			if from.y < 30:
				to = from + Vector2(randf_range(-5, 5), -9)
			if TABLE_AREA.grow(-4).has_point(to) and not _in_basket(to, 5.0):
				_place(o, "table", to, -1, false)
				_flights.append({"i": i, "from": from, "t": 0.0})
				Audio.play("gather")
			else:
				_place(o, "basket", o["home"], -1, false)
				_flights.append({"i": i, "from": from, "t": 0.0})
				Audio.play("expelled")
				_say("Жаба втекла назад у кошик. Клади її одразу на дошку.")


func _scale() -> float:
	return maxf(1.0, floorf(minf(size.x / W, size.y / H)))


func _offset() -> Vector2:
	return ((size - Vector2(W, H) * _scale()) / 2).floor()


func _to_logical(p: Vector2) -> Vector2:
	return (p - _offset()) / _scale()


## A random point on the liquid, at most `r` from the middle.
func _on_liquid(r: float = LIQ_R - 2) -> Vector2:
	var a := randf() * TAU
	return CAULDRON + Vector2(cos(a), sin(a)) * sqrt(randf()) * r


## A velocity pointing in a random direction.
func _radial(lo: float, hi: float) -> Vector2:
	var a := randf() * TAU
	return Vector2(cos(a), sin(a)) * randf_range(lo, hi)


func _clamp_to_liquid(p: Vector2, r: float) -> Vector2:
	var d := p - CAULDRON
	if d.length() > r:
		d = d.normalized() * r
	return CAULDRON + d


## A ring spreading on the liquid in the cauldron.
func _ripple(at: Vector2, col: Color) -> void:
	_ripples.append({"p": _clamp_to_liquid(at, LIQ_R - 4), "t": 0.0, "c": col.lightened(0.35)})


## Something fell into the cauldron: a ring and a few drops jumping out.
func _splash(at: Vector2, col: Color, drops: int = 4) -> void:
	_ripple(at, liquid_color())
	for k in drops:
		_particles.append({"p": at + Vector2(randf_range(-1, 1), randf_range(-1, 1)), "v": _radial(16, 30), "life": 0.4, "l0": 0.4, "c": col.lerp(liquid_color(), 0.5).lightened(0.2), "drag": 5.0, "big": true})


## Embers from the fire, air blown into it, sparkles of magic while the potion is in the right heat.
func _update_fire_fx(delta: float, _hot: float) -> void:
	var fire := _fire()
	if randf() < delta * (1.0 + fire * 16):
		var a := randf() * TAU
		var dir := Vector2(cos(a), sin(a))
		_particles.append({"p": CAULDRON + dir * (POT_R + 2), "v": dir * randf_range(6, 14) * (0.6 + fire) + Vector2(0, -3), "life": randf_range(0.5, 1.0), "c": C_FIRE[1], "ember": true, "sway": randf() * TAU})
	if _pumping() and randf() < delta * 16:
		var life := 0.3
		_particles.append({"p": Vector2(BELLOWS_REST.get_center().x + randf_range(-2, 2), BELLOWS_REST.position.y - 7), "v": Vector2(randf_range(-8, 8), randf_range(-45, -30)), "life": life, "l0": life, "c": Color(0.9, 0.86, 0.8, 0.5), "air": true})
	# Visual cues of the heat: sparkles while it is right (many, golden near the middle = best quality),
	# dark smoke and big bubbles when it is too hot.
	if step == Step.HEAT and _temp >= _zone.x and _temp <= _zone.y and _boil <= 0:
		var sweet := quality.is_sweet(_temp)
		if randf() < delta * (14.0 if sweet else 5.0):
			_particles.append({"p": _on_liquid(), "v": _radial(3, 8), "life": randf_range(0.5, 0.8), "c": Color("fff0a0") if sweet and randf() < 0.5 else potion_color.lightened(0.45), "star": randf() < (0.8 if sweet else 0.3), "drag": 1.5})
	if step == Step.HEAT and _temp > _zone.y and _boil <= 0 and randf() < delta * 10 * (_temp - _zone.y) / maxf(0.05, 1.0 - _zone.y):
		var life := randf_range(0.8, 1.3)
		_particles.append({"p": _on_liquid(), "v": Vector2(randf_range(2, 6), randf_range(-8, -4)), "life": life, "l0": life, "c": Color(0.18, 0.15, 0.13, 0.55), "steam": true, "sway": randf() * TAU})


## Bubbles that grow and pop while the potion is hot, rings on the liquid, ripples from the spoon.
func _update_surface(delta: float, hot: float) -> void:
	if step >= Step.HEAT and step <= Step.COOL and hot > 0.3 and randf() < delta * hot * 9:
		_bubbles.append({"p": _on_liquid(LIQ_R - 3), "t": 0.0, "s": randf_range(0.7, 1.2)})
	for b in _bubbles:
		b["t"] = float(b["t"]) + delta * (1.2 + hot * 2.0) * float(b["s"])
		if b["t"] >= 1.0:
			for k in 3:
				_particles.append({"p": Vector2(b["p"]), "v": _radial(6, 12), "life": 0.2, "l0": 0.2, "c": liquid_color().lightened(0.4), "drag": 6.0})
	_bubbles = _bubbles.filter(func(b): return b["t"] < 1.0)
	if step == Step.STIR and _stir_speed > 0.15:
		if randf() < delta * 10 * _stir_speed:
			_ripple(CAULDRON + Vector2(cos(_stir_angle), sin(_stir_angle)) * 7, liquid_color())
		if _stir_speed > 0.55 and randf() < delta * 6:
			# A drop flung over the rim along the swirl.
			var a := _stir_angle + randf_range(-0.4, 0.4)
			var dir := Vector2(cos(a), sin(a))
			_particles.append({"p": CAULDRON + dir * (LIQ_R - 1), "v": (dir + dir.orthogonal() * 0.6) * randf_range(14, 22), "life": 0.45, "l0": 0.45, "c": liquid_color().lightened(0.2), "drag": 4.0, "big": true})
	for r in _ripples:
		r["t"] = float(r["t"]) + delta * 1.8
	_ripples = _ripples.filter(func(r): return r["t"] < 1.0)


## How strong the fire under the cauldron is (0..1).
func _fire() -> float:
	if step >= Step.HEAT and step <= Step.COOL:
		return _temp
	return 0.05 if step >= Step.POUR else 0.08


func liquid_color() -> Color:
	match step:
		Step.PREP:
			return C_WATER.lerp(potion_color.darkened(0.35), 0.4 * _added / maxf(1.0, _ing_total()))
		Step.STIR:
			return _mix_start.lerp(potion_color.darkened(0.35), _stir)
		Step.HEAT:
			var c := potion_color.darkened(0.35).lerp(potion_color.darkened(0.1), _heat)
			# Too hot: the potion turns dark and murky (a cue to ease off), more so after every boil-over.
			if _temp > _zone.y:
				c = c.lerp(Color("2a2018"), 0.55 * (_temp - _zone.y) / maxf(0.05, 1.0 - _zone.y))
			return c.lerp(Color("4a4038"), 0.12 * mini(quality.boils, GameData.SPOIL_BOILS))
		Step.COOL:
			return potion_color.darkened(0.1).lerp(potion_color.lightened(0.08), _cool)
	return potion_color.lightened(0.08)


## The ingredient as it lies on the table: its 16x16 top-down sprite (tools/icons/gen_table_sprites.py), or the item
## icon for anything without one.
static func table_texture(id: String) -> AtlasTexture:
	var k := TABLE_SPRITES.find(id)
	if k == -1:
		return GameData.icon_texture(id)
	var atlas := AtlasTexture.new()
	atlas.atlas = TABLE_SHEET
	atlas.region = Rect2(k * ICON, 0, ICON, ICON)
	return atlas


## The columns of the table sprite the ingredient covers: Vector2(first, last + 1), in 0..ICON (where cuts can go).
static func table_span(id: String) -> Vector2:
	if _span_cache.has(id):
		return _span_cache[id]
	var span := Vector2(1, ICON - 1)
	var k := TABLE_SPRITES.find(id)
	if k != -1:
		var img := TABLE_SHEET.get_image()
		if img.is_compressed():
			img.decompress()
		var x0 := ICON
		var x1 := 0.0
		for x in int(ICON):
			for y in int(ICON):
				if img.get_pixel(int(k * ICON) + x, y).a > 0.5:
					x0 = minf(x0, x)
					x1 = maxf(x1, x + 1)
		if x1 > x0 + 3:
			span = Vector2(x0 + 1, x1 - 1)
	_span_cache[id] = span
	return span


## Average colour of an ingredient's table sprite (for powder, slices, drops).
static func _icon_color(id: String) -> Color:
	if _color_cache.has(id):
		return _color_cache[id]
	var col := Color("6e8a3a")
	var tex: AtlasTexture = table_texture(id)
	var img: Image = tex.atlas.get_image() if tex.atlas else null
	if img:
		if img.is_compressed():
			img.decompress()
		img = img.get_region(Rect2i(tex.region))
		var sum := Vector3.ZERO
		var n := 0
		for y in range(0, img.get_height(), 2):
			for x in range(0, img.get_width(), 2):
				var c := img.get_pixel(x, y)
				if c.a > 0.5 and c.v > 0.15:
					sum += Vector3(c.r, c.g, c.b)
					n += 1
		if n > 0:
			sum /= n
			col = Color(sum.x, sum.y, sum.z)
			col.s = minf(1.0, col.s * 1.25)
	_color_cache[id] = col
	return col


## 0..1 how full the flask on the stand is.
func _fill() -> float:
	if step == Step.DONE:
		return 1.0
	if step != Step.POUR:
		return 0.0
	return float(_scoops) / SCOOPS


func _ing_total() -> int:
	if experiment:
		return GameData.EXPERIMENT_MAX
	var n := 0
	for o in _objs:
		if o["ing"]:
			n += 1
	return maxi(1, n)


# ---------- Drawing (logical 200x104 pixels, seen from above) ----------

func _draw() -> void:
	draw_set_transform(_offset(), 0.0, Vector2.ONE * _scale())
	_draw_table()
	_draw_basket()
	_draw_bin()
	_draw_board()
	_draw_mortar()
	_draw_saucers()
	_draw_station()
	_draw_thermo()
	_draw_rests()
	_draw_rack()
	_draw_bottle()
	_draw_objects()
	_draw_bellows()
	_draw_particles()
	_draw_hand()
	_draw_pointer()
	_draw_bar()
	_draw_quality()
	draw_set_transform(Vector2.ZERO)


func _draw_quality() -> void:
	if step < Step.HEAT or (experiment and potion_id != "" and not GameData.RECIPES.has(potion_id)):
		return
	CraftQuality.draw_stars(_px, 150, 3, quality.quality(), _t)


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


## Cutting board seen from above; the knife lies to the right of it while it is not in the hand.
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
	_px(b.x - 6, b.y + 3, 3, 1, C_WOOD.darkened(0.25))
	_px(b.x + 4, b.y - 5, 2, 1, C_WOOD.darkened(0.25))
	if _tool == "knife":
		# Little notches on the edge of the board: where even cuts would go.
		for k in _cuts:
			var on_board := _on("board")
			var span := table_span(_objs[on_board]["id"]) if on_board != -1 else Vector2(0, ICON)
			_px(roundf(b.x - ICON / 2.0 + span.x + (k + 1) * (span.y - span.x) / (_cuts + 1.0)), b.y - 8, 1, 2, C_WOOD.darkened(0.45))
	if _tool != "knife":
		_glow_rest("knife", Rect2(KNIFE_REST.x - 2, KNIFE_REST.y - 1, 6, 16))
		_knife_at(KNIFE_REST, false)


## A soft light under a tool that is needed now or is under the mouse.
func _glow_rest(tool: String, r: Rect2) -> void:
	var wanted := _wanted_tool() == tool
	var hover := not _pressed and _held == -1 and _tool_rest_at(_mouse) == tool
	if wanted or hover:
		var a := 0.22 + (0.12 * sin(_t * 5) if wanted else 0.0)
		_px(r.position.x - 1, r.position.y - 1, r.size.x + 2, r.size.y + 2, Color(1.0, 0.85, 0.4, a))


## The tool the player should pick up now ("" = none in particular).
func _wanted_tool() -> String:
	match step:
		Step.PREP:
			if _held != -1 or _tool != "":
				return ""
			var b := _on("board")
			if b != -1 and _objs[b]["kind"] == "raw":
				return "knife"
			var m := _on("mortar")
			if m != -1 and not (_objs[m]["kind"] in READY):
				return "pestle"
			if _added > 0 and _all_in():
				return "spoon"
		Step.STIR:
			return "" if _tool == "spoon" else "spoon"
		Step.HEAT:
			return "" if _tool == "bellows" else "bellows"
		Step.POUR:
			if _flask_on and _scoops < SCOOPS and _tool != "ladle":
				return "ladle"
	return ""


func _draw_mortar() -> void:
	var c := MORTAR + Vector2(roundf(sin(_t * 70)) if _wobble > 0 else 0.0, 0)
	_ellipse(c.x + 2, c.y + 3, MORTAR_R, MORTAR_R - 1, Color(0, 0, 0, 0.3))
	_ellipse(c.x, c.y, MORTAR_R + 1, MORTAR_R + 1, C_OUT)
	_shaded(c, MORTAR_R, [C_STONE1, C_STONE2, C_STONE3, C_STONE4], 8.0)
	_shaded(c, 8.0, [C_STONE3, C_STONE4, C_STONE5], 0.0, true)
	_ellipse(c.x, c.y, 3, 3, C_STONE5.darkened(0.2))
	if _tool != "pestle":
		# The pestle leans on the rim.
		var tip := MORTAR + Vector2(4, -4)
		var top := MORTAR + Vector2(11, -11)
		_glow_rest("pestle", Rect2(top.x - 4, top.y - 4, 8, 8))
		_pestle_at(tip, top)


func _pestle_at(tip: Vector2, top: Vector2) -> void:
	_ellipse(tip.x, tip.y, 2, 2, C_OUT)
	_ellipse(tip.x, tip.y, 1, 1, C_STONE2)
	_line(tip, top, C_OUT, 4)
	_line(tip, top, C_STONE2, 2)
	_line(tip + Vector2(-1, -1), top + Vector2(-1, -1), C_STONE1, 1)
	_ellipse(top.x, top.y, 3, 3, C_OUT)
	_ellipse(top.x, top.y, 2, 2, C_STONE2)
	_px(top.x - 1, top.y - 1, 2, 1, C_STONE1)


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


func _draw_saucers() -> void:
	for i in SAUCERS.size():
		var k := _on("saucer", i)
		if _with_saucer() and int(_origin.get("slot", -1)) == i:
			# Its place while it is carried: a faint ring on the table.
			_ring_free(SAUCERS[i], SAUCER_R, Color(0, 0, 0, 0.25))
			continue
		_saucer_at(SAUCERS[i], false)
		if k == -1 and _held != -1 and _objs[_held]["kind"] in READY and not _with_saucer():
			_ring_free(SAUCERS[i], SAUCER_R + 2, Color(1.0, 0.85, 0.4, 0.35 + 0.2 * sin(_t * 5)))


## Spoon, bellows and ladle lying under the cauldron, the rack of empty flasks, the dish of corks.
func _draw_rests() -> void:
	# A strip of cloth the tools lie on.
	_px(96, 77, 76, 15, Color(0, 0, 0, 0.25))
	_px(95, 76, 76, 15, Color("4a3a2c"))
	_px(96, 77, 74, 13, Color("5e4a36"))
	for i in 9:
		_px(98 + i * 8, 77, 1, 13, Color("54422f"))
	if _tool != "spoon":
		_glow_rest("spoon", SPOON_REST)
		var a := SPOON_REST.position + Vector2(3, 5)
		var b := SPOON_REST.position + Vector2(21, 3)
		_line(a, b, C_OUT, 3)
		_line(a, b, C_WOOD2, 1)
		_ellipse(a.x, a.y, 3, 2, C_OUT)
		_ellipse(a.x, a.y, 2, 1, C_WOOD)
	if _tool != "bellows":
		_glow_rest("bellows", BELLOWS_REST)
		_bellows_at(BELLOWS_REST.position + Vector2(10, 6), Vector2(1, 0), 0.0)
	if _tool != "ladle":
		_glow_rest("ladle", LADLE_REST)
		_ladle_at(LADLE_REST.position + Vector2(5, 5), false, false)
	# Corks in a little dish.
	var c := CORKS
	_ellipse(c.x + 1, c.y + 2, 8, 7, Color(0, 0, 0, 0.3))
	_ellipse(c.x, c.y, 9, 9, C_OUT)
	_shaded(c, 8, [C_STONE1, C_STONE2, C_STONE3, C_STONE4], 6)
	_ellipse(c.x, c.y, 6, 6, C_STONE5)
	for i in 4:
		var p: Vector2 = c + [Vector2(-3, -2), Vector2(2, -3), Vector2(-1, 2), Vector2(3, 2)][i]
		if i == 3 and (_carry == "cork" or step == Step.DONE):
			continue
		_cork_at(p, 2.0)
	if step == Step.POUR and _flask_on and _scoops >= SCOOPS and _carry == "":
		_ring_free(c, 10, Color(1.0, 0.85, 0.4, 0.4 + 0.2 * sin(_t * 5)))


func _cork_at(p: Vector2, r: float) -> void:
	_ellipse(p.x, p.y, r + 1, r + 1, C_OUT)
	_ellipse(p.x, p.y, r, r, C_WOOD)
	_px(p.x - 1, p.y - 1, 2, 1, C_WOOD2)


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


## The ladle with its cup at `p`, the handle going down right.
func _ladle_at(p: Vector2, lifted: bool, full: bool) -> void:
	var cup := 4.0 if lifted else 3.0
	var handle := p + Vector2(14, 3)
	if lifted:
		_shadow(p + Vector2(3, 5), 4, 3)
		handle = p + Vector2(13, 8)
	_line(p, handle, C_OUT, 3)
	_line(p, handle, C_STONE3, 1)
	_ellipse(p.x, p.y, cup + 1, cup + 1, C_OUT)
	_ellipse(p.x, p.y, cup, cup, C_IRON3)
	_ellipse(p.x, p.y, cup - 1, cup - 1, potion_color if full else C_IRON)
	if full:
		_px(p.x - 1, p.y - 1, 2, 1, potion_color.lightened(0.4))


## The shelf with empty flasks (top right) and the leather mat where a flask is filled.
func _draw_rack() -> void:
	var r := RACK
	_px(r.position.x + 1, r.position.y + 2, r.size.x, r.size.y, Color(0, 0, 0, 0.3))
	_px(r.position.x - 1, r.position.y - 1, r.size.x + 2, r.size.y + 2, C_OUT)
	_px(r.position.x, r.position.y, r.size.x, r.size.y, C_WOOD)
	_px(r.position.x, r.position.y, r.size.x, 1, C_WOOD2)
	_px(r.position.x + 1, r.position.y + 2, r.size.x - 2, r.size.y - 4, C_TABLE_DARK)
	for i in 2:
		if i < _flask_taken or (i == 0 and _carry == "flask"):
			_ring_free(r.position + Vector2(7 + i * 11, 8.5), 4, Color(0, 0, 0, 0.3))
			continue
		_flask_at(r.position + Vector2(7 + i * 11, 8.5), 5.0, 0.0)
	if step == Step.POUR and not _flask_on and _carry == "":
		_px(r.position.x - 2, r.position.y - 2, r.size.x + 4, r.size.y + 4, Color(1.0, 0.85, 0.4, 0.15 + 0.1 * sin(_t * 5)))
	# The mat.
	var c := STAND
	_ellipse(c.x, c.y, 10, 10, C_OUT)
	_ellipse(c.x, c.y, 9, 9, C_LEATHER.darkened(0.2))
	_ellipse(c.x, c.y, 7, 7, C_LEATHER)
	for i in 12:
		var a := i * TAU / 12.0
		_px(roundf(c.x + cos(a) * 8), roundf(c.y + sin(a) * 8), 1, 1, C_WOOD2.darkened(0.2))
	if _carry == "flask" or (_carry == "cork"):
		_ring_free(c, 11, Color(1.0, 0.85, 0.4, 0.4 + 0.2 * sin(_t * 5)))


## An empty or filled round flask seen from above.
func _flask_at(c: Vector2, r: float, fill: float) -> void:
	_ellipse(c.x, c.y, r + 1, r + 1, C_STONE5)
	_ellipse(c.x, c.y, r, r, Color("2a3a40"))
	if fill > 0:
		_ellipse(c.x, c.y, r - 1, r - 1, Color(potion_color.darkened(0.2), 0.5 + 0.5 * fill))
		var sr := (r - 1) * (0.35 + 0.65 * fill)
		_ellipse(c.x, c.y, sr, sr, potion_color)
		if fill < 1.0:
			_ring_free(c, sr + (1 if fmod(_t * 10, 2.0) > 1.0 else 0), potion_color.lightened(0.3))
	_px(c.x - r + 2, c.y - 3, 1, 3, Color(1, 1, 1, 0.5))
	_px(c.x - 3, c.y - r + 2, 3, 1, Color(1, 1, 1, 0.5))
	var neck := maxf(2.0, r * 0.4)
	_ellipse(c.x, c.y, neck, neck, C_STONE5)
	_ellipse(c.x, c.y, neck - 1, neck - 1, Color("1a2428") if fill <= 0.0 else potion_color.darkened(0.3))


## The flask on the mat, the cork going in at the end.
func _draw_bottle() -> void:
	if not _flask_on and step != Step.DONE:
		return
	var c := STAND
	var hop := _bottle_hop()
	var r := 7.0 + hop
	if step == Step.DONE and _done_t > CORK_TIME:
		var t := _done_t - CORK_TIME
		var ray_len := minf(1.0, t * 3.0) * 6.0
		var alpha := 0.3 * clampf(1.2 - t * 0.6, 0.3, 1.0)
		for i in 8:
			var a := i * TAU / 8.0 + t * 0.8
			var from := c + Vector2(cos(a), sin(a)) * 10
			_line(from, from + Vector2(cos(a), sin(a)) * ray_len * (0.6 if i % 2 else 1.0), Color(potion_color.lightened(0.5), alpha), 1)
	_shadow(c + Vector2(2, 3), r, r - 1)
	_flask_at(c, r, _fill())
	if step == Step.DONE:
		var k := clampf(_done_t / CORK_TIME, 0.0, 1.0)
		var cr := 2.0 + (1.0 - k * k) * 3.0
		var cp := c + Vector2(1, -1) * (1.0 - k) * 4
		_cork_at(cp, cr)
		if _done_t > CORK_TIME:
			var glow := 0.25 + 0.15 * sin(_t * 4)
			_ellipse(c.x, c.y, r + 2, r + 2, Color(potion_color, glow * 0.4))


## Where a thing is drawn now (it slides to its place after a drop).
func _shown_pos(i: int) -> Vector2:
	var pos: Vector2 = _objs[i]["pos"]
	for f in _flights:
		if int(f["i"]) == i:
			var k := float(f["t"])
			return (Vector2(f["from"]).lerp(pos, k) + Vector2(0, -sin(k * PI) * 4)).round()
	return pos


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
		if i == hover and where != "mortar":
			_shadow(pos + Vector2(2, 4), 4, 2)
			pos += Vector2(0, -1)
		_draw_thing(o, pos, where == "mortar", 1.0)


## One thing at `pos` (its centre). `small`: inside the mortar; `lift` > 1: carried, nearer to the camera.
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
				# The knife marks.
				for c in cuts:
					var k := cuts.find(c)
					var sorted_before := 0
					for other in cuts:
						if float(other) < float(c):
							sorted_before += 1
					var cx := pos.x - ICON / 2.0 - (cuts.size()) / 2.0 + float(c) + sorted_before
					_px(roundf(cx), pos.y - ICON / 2.0 - 1, 1, ICON + 2, Color(0.1, 0.05, 0.02, 0.55 if k >= 0 else 0.0))
			elif small and o["act"] == "squeeze":
				# Squashed flatter with every press, juice spreading under it.
				var w := float(o["work"])
				_ellipse(pos.x, pos.y, 1 + 5 * w, 1 + 5 * w, col.darkened(0.25))
				var sq := 1.0 - 0.5 * w
				draw_texture_rect(tex, Rect2(pos.x - s * (2.0 - sq) / 2.0, pos.y - s * sq / 2.0, s * (2.0 - sq), s * sq), false)
			elif small and float(o["work"]) > 0.0:
				_draw_grinding(o, pos)
			elif int(o["hits"]) > 0:
				# Cracked: the pieces drift apart.
				var src := Vector2(tex.get_width(), tex.get_height())
				var gap := float(o["hits"])
				for k in 4:
					var q := Vector2(k % 2, int(k / 2.0))
					var d := (q - Vector2(0.5, 0.5)) * gap
					draw_texture_rect_region(tex, Rect2(pos - Vector2(s, s) / 2.0 + q * s / 2.0 + d, Vector2(s, s) / 2.0), Rect2(src * q / 2.0, src / 2.0))
			else:
				var r := Rect2(pos - Vector2(s, s) / 2.0, Vector2(s, s))
				if String(o["id"]) in GameData.BREW_RUNAWAY and (o["where"] == "table" or o["where"] == "board"):
					# The toad breathes, and crouches just before it jumps.
					var limit := TOAD_BOARD if o["where"] == "board" else TOAD_HOP
					if float(o["t"]) > limit - 0.35:
						r = Rect2(r.position + Vector2(-1, 1), r.size + Vector2(2, -1))
				if int(o["plucks"]) > 0 and _hop > 0.3:
					r.position.x += roundf(sin(_t * 60))
				draw_texture_rect(tex, r, false, Color(1, 1, 1, 0.45 + 0.55 * dose) if o["act"] == "sprinkle" else Color.WHITE)
		"leaves":
			if small and float(o["work"]) > 0.0:
				_draw_grinding(o, pos)
			else:
				for k in 7:
					var a := k * 0.9 + int(o["seed"])
					var p := pos + Vector2(cos(a), sin(a) * 0.8) * (1.5 + (k % 3) * 1.4) * (0.8 if small else 1.0)
					_px(p.x - 1, p.y, 3, 1, col.darkened(0.15))
					_px(p.x, p.y - 1, 1, 3, col)
					_px(p.x, p.y, 1, 1, col.lightened(0.25))
		"slices":
			_draw_slices(tex, pos, o["cuts"], 1.5 * lift, dose)
		"powder":
			var pr := (1.5 + 3.0 * dose) * (0.85 if small else 1.0) * lift
			_ellipse(pos.x, pos.y, pr + 1, pr, col.darkened(0.25))
			_ellipse(pos.x, pos.y, pr, pr - 1, col.lightened(0.15))
			_ellipse(pos.x - 1, pos.y - 1, pr * 0.5, pr * 0.4, col.lightened(0.35))
			for k in 4:
				var a := k * 1.7 + int(o["seed"])
				_px(pos.x + cos(a) * (pr + 1), pos.y + sin(a) * pr, 1, 1, col.lightened(0.1))
		"pulp":
			var pr := (1.5 + 3.0 * dose) * (0.85 if small else 1.0) * lift
			_ellipse(pos.x, pos.y, pr + 1, pr, col.darkened(0.4))
			_ellipse(pos.x, pos.y, pr, pr - 1, col.darkened(0.1))
			_px(pos.x - 2, pos.y - 1, 2, 1, col.lightened(0.45))
			_px(pos.x + 1, pos.y + 1, 1, 1, col.lightened(0.2))
		"waste":
			if tex == null:
				# Bare stems.
				for k in 3:
					var a := pos + Vector2(-4 + k, -3 + k * 2)
					_line(a, a + Vector2(8 - k, 2 - k), Color("3a4420"), 1)
					_px(a.x + 2, a.y, 2, 1, Color("6a7a3a"))
			else:
				var r := Rect2(pos - Vector2(s, s) / 2.0, Vector2(s, s))
				draw_texture_rect(tex, r, false, Color(0.55, 0.5, 0.45, 0.6))


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


## In the mortar: chunks that turn into powder as the pestle works.
func _draw_grinding(o: Dictionary, pos: Vector2) -> void:
	var col: Color = o["col"]
	var w := float(o["work"])
	var powder := col.lightened(0.15)
	var pr := 1.0 + 5.0 * minf(1.0, w * 1.4)
	_ellipse(pos.x, pos.y, pr, pr, powder)
	_ellipse(pos.x - 1, pos.y - 1, pr * 0.5, pr * 0.5, powder.lightened(0.15))
	var n := 9
	for k in n:
		var a := k * 2.4 + int(o["seed"])
		var p := pos + Vector2(cos(a), sin(a)) * (1.0 + (k % 4) * 1.3)
		if k >= int(n * w):
			_px(p.x, p.y, 2, 2, col.darkened(0.1))
			_px(p.x, p.y, 1, 1, col.lightened(0.25))
		else:
			_px(p.x, p.y, 1, 1, powder.lightened(0.2))


## The bellows at the fire while they are in the hand: they squeeze as long as the button is held.
func _draw_bellows() -> void:
	if _tool != "bellows":
		return
	var squeeze := 0.5 + 0.5 * sin(_t * 14) if _pumping() else 0.0
	var c := Vector2(BELLOWS_REST.get_center().x, BELLOWS_REST.position.y + 3)
	var dir := Vector2(0, -1)
	_shadow(c + Vector2(2, 4), 6, 8)
	_bellows_at(c, dir, squeeze)


## What is in the hand, drawn at the mouse: a carried thing (with its saucer), a tool, a flask or a cork.
func _draw_hand() -> void:
	var m := _mouse.round()
	if _held != -1:
		var o: Dictionary = _objs[_held]
		if _with_saucer():
			var tip := m.distance_to(CAULDRON) < POT_R + 2
			var c := m + (Vector2(-1, 1) if tip and fmod(_t * 12, 2.0) > 1.0 else Vector2.ZERO)
			_saucer_at(c, true)
			if float(o["dose"]) > 0.0:
				_draw_thing(o, c, false, 1.0)
		else:
			_shadow(m + Vector2(3, 5), 4, 2)
			var p := m + Vector2(0, -1)
			if _sprinkled(o) and m.distance_to(CAULDRON) < POT_R + 2:
				p += Vector2(0, roundf(sin(_t * 30)))
			_draw_thing(o, p, false, 1.2)
	match _tool:
		"knife":
			_knife_at(Vector2(m.x - 1, m.y - 3), _knife <= 0.0)
		"pestle":
			var tip := _pestle if m.distance_to(MORTAR) < MORTAR_R + 4 else m
			if _knife > 0.0:
				tip += Vector2(0, 1)
			else:
				_shadow(tip + Vector2(2, 3), 2, 1)
			_pestle_at(tip, tip + Vector2(5, -7))
		"spoon":
			_draw_spoon(m)
		"ladle":
			_ladle_at(m, true, _ladle_full)
	if _carry == "flask":
		_shadow(m + Vector2(3, 5), 6, 4)
		_flask_at(m + Vector2(0, -1), 7.0, 0.0)
	elif _carry == "cork":
		_shadow(m + Vector2(2, 4), 3, 2)
		_cork_at(m + Vector2(0, -1), 3.0)


## The spoon in the hand: in the cauldron its bowl follows the stirring.
func _draw_spoon(m: Vector2) -> void:
	var tip := m
	var end := m + Vector2(14, -14)
	if step == Step.STIR and m.distance_to(CAULDRON) < 26:
		var dir := Vector2(cos(_stir_angle), sin(_stir_angle))
		tip = CAULDRON + dir * 7
		end = CAULDRON + dir.rotated(-0.15 * _stir_speed) * (POT_R + 9)
	else:
		_shadow(tip + Vector2(3, 5), 3, 2)
	_line(tip, end, C_OUT, 3)
	_line(tip, end, C_WOOD2, 1)
	_ellipse(tip.x, tip.y, 2, 2, C_OUT)
	_ellipse(tip.x, tip.y, 1, 1, C_WOOD)
	_px(end.x - 1, end.y - 1, 3, 3, C_OUT)
	_px(end.x, end.y, 1, 1, C_WOOD)


## Bobbing arrow above the thing to use now.
func _draw_pointer() -> void:
	var at := Vector2.ZERO
	match _wanted_tool():
		"knife":
			at = KNIFE_REST + Vector2(1, -8)
		"pestle":
			at = MORTAR + Vector2(11, -20)
		"spoon":
			at = Vector2(SPOON_REST.get_center().x, SPOON_REST.position.y - 7)
		"bellows":
			at = Vector2(BELLOWS_REST.get_center().x, BELLOWS_REST.position.y - 6)
		"ladle":
			at = Vector2(LADLE_REST.get_center().x, LADLE_REST.position.y - 6)
		_:
			match step:
				Step.STIR:
					at = CAULDRON + Vector2(0, -HEARTH_R - 2)
				Step.HEAT:
					at = Vector2(THERMO.get_center().x, THERMO.position.y - 7)
				Step.COOL:
					var x := CAULDRON.x - HEARTH_R - 4 + roundf(sin(_t * 4))
					_px(x - 1, CAULDRON.y, 3, 1, Color("eadbc8"))
					_px(x + 3, CAULDRON.y - 1, 2, 1, Color("eadbc8", 0.6))
					_px(x + 3, CAULDRON.y + 1, 2, 1, Color("eadbc8", 0.6))
				Step.POUR:
					if not _flask_on and _carry == "":
						at = Vector2(RACK.get_center().x, RACK.end.y + 3)
	if at == Vector2.ZERO:
		return
	var y := at.y + roundf(sin(_t * 5))
	for i in 4:
		_px(at.x - 3 + i, y + i, 7 - i * 2, 1, Color("f2c14e"))


func _draw_bar() -> void:
	# Five step pips and the progress of the current step, on a dark strip.
	_px(96, 94, 76, 8, Color(0, 0, 0, 0.35))
	for i in 5:
		var done := i < step
		var cur := i == step
		var col := C_GREEN if done else (Color("f2c14e") if cur else C_TABLE_DARK)
		_px(99 + i * 6, 96, 4, 4, C_OUT)
		_px(100 + i * 6, 97, 2, 2, col)
	_px(131, 96, 38, 4, C_OUT)
	_px(132, 97, 36 * progress(), 2, Color("f2c14e"))


func _draw_particles() -> void:
	for p in _particles:
		var c: Color = p["c"]
		var life: float = p["life"]
		var pos: Vector2 = p["p"]
		var k := clampf(life / float(p.get("l0", 1.0)), 0.0, 1.0)
		if p.has("steam"):
			# A puff swells as it rises to the camera and fades.
			var s := 1.0 + floorf((1.0 - k) * 2.5)
			_px(pos.x - floorf(s / 2), pos.y - floorf(s / 2), s, s, Color(c, c.a * k))
			continue
		if p.has("air"):
			_px(pos.x, pos.y, 2 + floorf(k * 2), 1, Color(c, c.a * k))
			continue
		if p.has("ember"):
			c = C_FIRE[1] if life > 0.6 else (C_FIRE[2] if life > 0.3 else C_FIRE[3])
		if p.get("star", false) and life > 0.15:
			# A little four-pointed twinkle.
			_px(pos.x - 1, pos.y, 3, 1, Color(c, c.a * 0.7))
			_px(pos.x, pos.y - 1, 1, 3, Color(c, c.a * 0.7))
		# Drops near the camera are bigger: falling into the pot they shrink, jumping out they start big.
		if (p.get("into", false) and k > 0.5) or (p.get("big", false) and k > 0.55):
			_px(pos.x, pos.y, 2, 2, c)
		else:
			_px(pos.x, pos.y, 1, 1, c)


## A soft dark spot on the table under something lifted.
func _shadow(c: Vector2, rx: float, ry: float) -> void:
	_ellipse(c.x, c.y, rx, ry, Color(0, 0, 0, 0.25))


## Circle outline made of single pixels (rings on the liquid, bubbles), clipped to the liquid.
func _ring(c: Vector2, r: float, col: Color) -> void:
	var n := maxi(8, int(r * 6))
	for i in n:
		var a := i * TAU / n
		var p := (c + Vector2(cos(a), sin(a)) * r).round()
		if p.distance_to(CAULDRON) <= LIQ_R - 0.5:
			_px(p.x, p.y, 1, 1, col)


func _px(x: float, y: float, w: float, h: float, c: Color) -> void:
	draw_rect(Rect2(floorf(x), floorf(y), w, h), c)


## Filled ellipse made of whole-pixel rows.
func _ellipse(cx: float, cy: float, rx: float, ry: float, c: Color) -> void:
	for y in range(-int(ry), int(ry) + 1):
		var t := float(y) / (ry + 0.5)
		var hw := floorf((rx + 0.5) * sqrt(maxf(0.0, 1.0 - t * t)))
		_px(cx - hw, cy + y, hw * 2 + 1, 1, c)


## A disc / ring lit from the top left: `cols` from lit to dark; `inner` > 0 leaves a hole,
## `concave` lights the far (bottom right) side instead, like the inside of a bowl.
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


## Pixel line (Bresenham) of the given thickness.
func _line(a: Vector2, b: Vector2, c: Color, w: int) -> void:
	var steps := int(maxf(absf(b.x - a.x), absf(b.y - a.y)))
	for i in steps + 1:
		var p := a.lerp(b, float(i) / maxf(1.0, steps))
		_px(p.x - (w - 1) / 2.0, p.y - (w - 1) / 2.0, w, w, c)


## The alchemy table seen from above: planks, the window light and dust motes floating in it.
func _draw_table() -> void:
	_px(0, 0, W, H, C_TABLE)
	for row in range(0, 11):
		var y := row * 10 - 2
		_px(0, y, W, 1, C_TABLE_DARK)
		_px(0, y + 1, W, 1, C_TABLE_TOP.darkened(0.25))
		# Plank ends and the wood grain.
		var off := (row * 47) % 61
		for x in range(off, W, 61):
			_px(x, y, 1, 10, C_TABLE_DARK)
			_px(x + 2, y + 4, 1, 1, C_SEAM)
		for g in 4:
			var gx := (row * 31 + g * 43) % W
			_px(gx, y + 3 + (g * 3) % 6, 6 + g * 2, 1, C_TABLE.darkened(0.2))
	# Darker edges, the light from the window on the right top.
	_px(0, 0, W, 1, C_SEAM)
	_px(0, H - 1, W, 1, C_SEAM)
	for i in 30:
		var y := i
		_px(150 + i, y, 50 - i, 1, Color(1.0, 0.9, 0.65, 0.05))
	for i in 6:
		var mx := 156 + fmod(i * 17.0 + _t * (1.5 + i % 3), 40.0)
		var my := 2 + fmod(i * 11.0 + _t * (2.0 + i % 2), 26.0) + sin(_t * 1.3 + i) * 1.5
		_px(mx, my, 1, 1, Color(0.85, 0.8, 0.65, 0.18 + 0.1 * sin(_t * 2 + i)))


func _draw_station() -> void:
	var c := CAULDRON
	var fire := _fire()
	var flick := 0.85 + 0.15 * sin(_t * 9) * sin(_t * 5.3)
	# Warm light of the fire spreading over the table, flickering.
	_ellipse(c.x, c.y, 44, 36, Color(1.0, 0.5, 0.15, (0.03 + 0.1 * fire) * flick))
	_ellipse(c.x, c.y, 34, 30, Color(1.0, 0.55, 0.2, (0.03 + 0.08 * fire) * flick))
	# Stone hearth: a ring of stones around the fire pit.
	_ellipse(c.x + 1, c.y + 2, HEARTH_R, HEARTH_R, Color(0, 0, 0, 0.3))
	_ellipse(c.x, c.y, HEARTH_R + 1, HEARTH_R + 1, C_OUT)
	_shaded(c, HEARTH_R, [C_STONE2, C_STONE3, C_STONE4, C_STONE5], HEARTH_R - 5)
	for i in 14:
		var a := i * TAU / 14.0 + 0.2
		var dir := Vector2(cos(a), sin(a))
		_line(c + dir * (HEARTH_R - 5), c + dir * HEARTH_R, C_OUT, 1)
	# The fire pit: coals glowing and flames licking out from under the cauldron.
	_ellipse(c.x, c.y, HEARTH_R - 5, HEARTH_R - 5, Color("1a0a05"))
	var heat := fire
	for i in 40:
		var a := i * TAU / 40.0
		var dir := Vector2(cos(a), sin(a))
		var len := 1.0 + heat * 4.0 + sin(_t * 13 + i * 1.7) * 1.2 + sin(_t * 7.3 + i * 0.9)
		len = clampf(len, 0.0, HEARTH_R - 5 - POT_R)
		var coal := C_FIRE[3].darkened(0.4) if (i * 7) % 3 else C_FIRE[3].darkened(0.1)
		_px(roundf(c.x + dir.x * (HEARTH_R - 6)), roundf(c.y + dir.y * (HEARTH_R - 6)), 1, 1, coal)
		for j in int(len):
			var k := float(j) / maxf(1.0, len)
			var col: Color = C_FIRE[0 if heat > 0.5 and j == 0 else 1] if k < 0.3 else (C_FIRE[2] if k < 0.7 else C_FIRE[3])
			var p := c + dir * (POT_R + 0.5 + j)
			_px(roundf(p.x), roundf(p.y), 1, 1, col)
	# Cauldron: a dark iron ring with ears, the rim catching the light, the liquid inside.
	var shake := Vector2(roundf(sin(_t * 50)) * (1 if _boil > 0 else 0), 0)
	var cc := c + shake
	for side in [-1.0, 1.0]:
		_ellipse(cc.x + side * (POT_R + 1), cc.y, 2, 3, C_OUT)
		_px(cc.x + side * (POT_R + 1) - 1, cc.y - 2, 2, 4, C_IRON3)
	_ellipse(cc.x, cc.y, POT_R + 1, POT_R + 1, C_OUT)
	_shaded(cc, POT_R, CraftQuality.pot_colors([C_IRON3, C_IRON2, C_IRON, C_IRON.darkened(0.3)]), LIQ_R + 1)
	# The fire lights the outside of the cauldron.
	if fire > 0.2:
		for i in 36:
			var a := i * TAU / 36.0
			var p := cc + Vector2(cos(a), sin(a)) * POT_R
			_px(roundf(p.x), roundf(p.y), 1, 1, Color(1.0, 0.5, 0.15, (0.2 + 0.4 * fire) * flick))
	# Inside wall (seen when the level drops) and the liquid.
	_ellipse(cc.x, cc.y, LIQ_R + 1, LIQ_R + 1, C_IRON.darkened(0.4))
	var lc := liquid_color()
	var level := 1.0 - _fill() * 0.9
	var lr := LIQ_R * (0.55 + 0.45 * level)
	var lo := Vector2(1, 1) * (1.0 - level) * 2.0
	_ellipse(cc.x + lo.x, cc.y + lo.y, lr, lr, lc)
	_ellipse(cc.x + lo.x + 1, cc.y + lo.y + 1, lr - 2, lr - 2, lc.darkened(0.08))
	# A glint of the window light on the surface, wobbling a bit.
	var g := cc + Vector2(-6, -6) * (lr / LIQ_R) + Vector2(roundf(sin(_t * 0.9) * 1.5), 0)
	_px(g.x, g.y, 3, 1, lc.lightened(0.3))
	_px(g.x - 1, g.y + 1, 2, 1, lc.lightened(0.18))
	# Swirl while stirring: two rings of herbs spinning, a dark funnel in the middle when stirred fast.
	if step == Step.STIR or (step == Step.PREP and _added > 0):
		var spin := _stir_angle if step == Step.STIR else _t * 0.6
		for i in 8:
			var r := 9.0 if i < 5 else 4.5
			var a := spin * (1.0 if i < 5 else 1.4) + i * TAU / (5.0 if i < 5 else 3.0)
			_px(cc.x + cos(a) * r, cc.y + sin(a) * r, 1, 1, herb_color.lightened(0.2 if i < 5 else 0.05))
		if step == Step.STIR and _stir_speed > 0.3:
			for j in 10:
				var a := _stir_angle * 1.6 + j * 0.7
				var r := j * 0.6
				_px(cc.x + cos(a) * r, cc.y + sin(a) * r, 1, 1, lc.darkened(0.25 + 0.03 * (10 - j)))
	# Rings spreading where something fell in.
	for r in _ripples:
		var t: float = r["t"]
		var col: Color = r["c"]
		_ring(Vector2(r["p"]) + shake, 1.0 + t * 6.0, Color(col, 0.8 * (1.0 - t)))
	# Bubbles: a dot, then a little round bubble that pops.
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
	if _boil > 0:
		# Foam all round the rim, drips creeping down the outside.
		for i in 14:
			var a := i * TAU / 14.0 + sin(_t * 3 + i) * 0.1
			var p := cc + Vector2(cos(a), sin(a)) * (LIQ_R + 1)
			_px(p.x - 1, p.y - 1, 3, 2, Color(lc.lightened(0.45), _boil))
		for i in 6:
			var a := i * TAU / 6.0 + 0.4
			var p := cc + Vector2(cos(a), sin(a)) * (LIQ_R + 2 + (1.0 - _boil) * 6)
			_px(p.x, p.y, 2, 2, Color(lc, minf(1.0, _boil * 2)))


func _draw_thermo() -> void:
	var r := THERMO
	_px(r.position.x, r.position.y + 1, r.size.x + 3, r.size.y + 7, Color(0, 0, 0, 0.3))
	_px(r.position.x - 1, r.position.y - 1, r.size.x + 2, r.size.y + 6, C_OUT)
	_px(r.position.x, r.position.y, r.size.x, r.size.y, Color("2a1c12"))
	# Green zone.
	var zy0 := r.end.y - r.size.y * _zone.y
	var zy1 := r.end.y - r.size.y * _zone.x
	_px(r.position.x, zy0, r.size.x, zy1 - zy0, C_GREEN.darkened(0.45))
	# The best heat: a lighter band in the middle of the zone (quality).
	var sweet := float(GameData.QUALITY["sweet"])
	var sy0 := r.end.y - r.size.y * (quality.centre() + sweet)
	var sy1 := r.end.y - r.size.y * (quality.centre() - sweet)
	_px(r.position.x, roundf(sy0), r.size.x, roundf(sy1) - roundf(sy0), C_GREEN.darkened(0.2))
	_px(r.position.x - 2, roundf((sy0 + sy1) / 2.0), 1, 1, C_GREEN.lightened(0.3))
	_px(r.position.x, r.position.y, r.size.x, 4, C_RED.darkened(0.4))
	# Mercury.
	var shown := _temp if step >= Step.HEAT else 0.0
	var hgt := floorf(r.size.y * clampf(shown, 0.0, 1.0))
	var in_zone := shown >= _zone.x and shown <= _zone.y
	var col := C_GREEN if in_zone else (C_RED if shown > _zone.y else Color("d0c0a0"))
	_px(r.position.x + 1, r.end.y - hgt, r.size.x - 2, hgt, col)
	_ellipse(r.get_center().x, r.end.y + 2, 3, 2, col)
	# The bulb glows while the heat is right, the top blinks red when it is too hot.
	if in_zone and step == Step.HEAT:
		_ellipse(r.get_center().x, r.end.y + 2, 5, 4, Color(C_GREEN, 0.2 + 0.15 * sin(_t * 8)))
	elif shown > _zone.y and fmod(_t * 6, 2.0) > 1.0:
		_px(r.position.x, r.position.y, r.size.x, 4, C_RED)
	# Ticks.
	for i in 5:
		_px(r.end.x + 1, r.position.y + i * r.size.y / 4.0, 2, 1, C_STONE4)


## Bottle hop after the cork goes in (0 when resting).
func _bottle_hop() -> float:
	if step != Step.DONE or _done_t < CORK_TIME:
		return 0.0
	var t := (_done_t - CORK_TIME) / 0.25
	return roundf(sin(minf(t, 1.0) * PI)) if t < 1.0 else 0.0


## Circle outline (not clipped).
func _ring_free(c: Vector2, r: float, col: Color) -> void:
	var n := maxi(8, int(r * 6))
	for i in n:
		var a := i * TAU / n
		_px(roundf(c.x + cos(a) * r), roundf(c.y + sin(a) * r), 1, 1, col)


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
