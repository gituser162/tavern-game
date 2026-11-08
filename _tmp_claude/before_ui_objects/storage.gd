extends RefCounted
## The tavern storage: several separate places (pantry, cellar, cabinet...), see GameData.STORAGES.
## Every place holds the item categories listed for it and has its own capacity.
## One piece of any item takes one place. Items are kept as counts: {item id: how many}.

const GameData := preload("res://scripts/game_data.gd")

var items: Dictionary = {}


func clear() -> void:
	items.clear()


func count(item_id: String) -> int:
	return items.get(item_id, 0)


## Id of the storage place where this item is kept.
static func place_of(item_id: String) -> String:
	return GameData.storage_of_category(GameData.ITEMS[item_id]["cat"])


func used(place_id: String) -> int:
	var n := 0
	for id in items:
		if place_of(id) == place_id:
			n += items[id]
	return n


func capacity(place_id: String) -> int:
	return GameData.STORAGES[place_id]["capacity"]


func free_space(place_id: String) -> int:
	return maxi(0, capacity(place_id) - used(place_id))


## True if n more pieces of this item fit into its storage place.
func can_fit(item_id: String, n: int = 1) -> bool:
	return free_space(place_of(item_id)) >= n


## Puts one piece into its storage place. Returns false (and changes nothing) if the place is full.
func add(item_id: String) -> bool:
	if not can_fit(item_id):
		return false
	items[item_id] = count(item_id) + 1
	return true


## Removes one piece of this item. Returns false if there is none.
func take(item_id: String) -> bool:
	if count(item_id) <= 0:
		return false
	items[item_id] -= 1
	if items[item_id] <= 0:
		items.erase(item_id)
	return true


## Item ids in storage of one category, each listed once, in the order of GameData.ITEMS.
func ids_in_category(cat: String) -> Array[String]:
	var result: Array[String] = []
	for id in GameData.items_of(cat):
		if count(id) > 0:
			result.append(id)
	return result


## Item ids kept in one storage place, in the order of GameData.ITEMS.
func ids_in_place(place_id: String) -> Array[String]:
	var result: Array[String] = []
	for cat in GameData.STORAGES[place_id]["cats"]:
		result.append_array(ids_in_category(cat))
	return result


func snapshot() -> Dictionary:
	return items.duplicate()


func restore(saved: Dictionary) -> void:
	items = saved.duplicate()
