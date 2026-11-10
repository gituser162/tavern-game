extends RefCounted
## What the brewing / cooking station measures for the quality of the result (GameData.QUALITY, GameState.craft_quality):
## the order the ingredients went in, how close to the middle of the green zone the heat was kept, how many times it
## boiled over / burned. Shared by brew_station.gd and cook_station.gd; they also draw its stars (draw_stars).

const GameData := preload("res://scripts/game_data.gd")

## The recipe's ingredients one piece at a time, in its order ([] = unknown yet, e.g. an experiment).
var expected: Array = []
## Ingredient ids in the order they were put in.
var added: Array = []
## Seconds of heating inside the green zone, and of those near its middle.
var zone_time := 0.0
var sweet_time := 0.0
var boils := 0
## The handiwork 0..1: even slices, full doses, a tidy table (set by the station when the preparing ends).
var prep := 1.0
## Green zone of the thermometer for this brew (already widened by the "Інструменти" upgrade).
var zone := Vector2(0.58, 0.84)


func reset(order: Array, heat_zone: Vector2) -> void:
	expected = order.duplicate()
	added.clear()
	zone_time = 0.0
	sweet_time = 0.0
	boils = 0
	prep = 1.0
	zone = heat_zone


## The green zone of a station widened on each side by the tools upgrade.
static func widened(base: Vector2) -> Vector2:
	var w := float(GameState.upgrade_value("tools", "zone"))
	return Vector2(maxf(0.2, base.x - w), minf(0.95, base.y + w))


func centre() -> float:
	return (zone.x + zone.y) / 2.0


## True if this temperature is near the middle of the green zone.
func is_sweet(temp: float) -> bool:
	return absf(temp - centre()) <= float(GameData.QUALITY["sweet"])


## Call every frame of the heating while the heat counts (in the zone, not boiling over).
func tick(delta: float, temp: float) -> void:
	zone_time += delta
	if is_sweet(temp):
		sweet_time += delta


## Share of the ingredients put in their place of the recipe's order (1.0 if the order is unknown).
func order_score() -> float:
	if expected.is_empty():
		return 1.0
	var hits := 0
	for i in mini(added.size(), expected.size()):
		if added[i] == expected[i]:
			hits += 1
	return float(hits) / maxf(1.0, expected.size())


func precision() -> float:
	return sweet_time / zone_time if zone_time > 0.0 else 0.0


## Quality 0..100 with what is measured so far.
func quality() -> int:
	return GameState.craft_quality(order_score(), precision(), boils, prep)


## The order as text: "Трави → Трави → Ягоди".
static func order_text(order: Array) -> String:
	var names: PackedStringArray = []
	for id in order:
		names.append(String(GameData.ITEMS[id]["name"]))
	return " → ".join(names)


## Three little pixel stars at (x, y) (logical pixels): the quality tier of `q`, drawn with the station's _px.
## A 5x5 star every 7 px; lit ones gold, others dark.
const STAR := ["..#..", ".###.", "#####", ".###.", ".#.#."]


static func draw_stars(px: Callable, x: float, y: float, q: int, t: float) -> void:
	var tier := GameData.quality_tier(q)
	var lit := int(tier[4])
	var col := Color(String(tier[3]))
	for i in 3:
		var sx := x + i * 7
		var c := col if i < lit else Color("3a2a1c")
		var o := Color("1a0f0a")
		# A 5x5 star with a dark outline:  ..#..  .###.  #####  .###.  .#.#.
		for r in STAR.size():
			var row: String = STAR[r]
			for k in row.length():
				if row[k] == "#":
					px.call(sx + k - 1, y + r, 3, 1, o)
					px.call(sx + k, y + r - 1, 1, 3, o)
		for r in STAR.size():
			var row: String = STAR[r]
			for k in row.length():
				if row[k] == "#":
					px.call(sx + k, y + r, 1, 1, c)
		if i < lit and i == lit - 1 and fmod(t, 1.6) < 0.25:
			px.call(sx + 2, y + 2, 1, 1, Color(1, 1, 0.9))


## Colours of the cauldron / pot by the "Інструменти" upgrade: iron, then copper, then polished copper.
static func pot_colors(iron: Array) -> Array:
	match int(GameState.upgrade_level("tools")):
		1:
			return [Color("c8865a"), Color("a8643a"), Color("7a4426"), Color("4e2a16")]
		2:
			return [Color("f0b880"), Color("d08850"), Color("9a5a30"), Color("5e341a")]
	return iron
