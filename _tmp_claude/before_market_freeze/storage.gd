extends RefCounted
## The tavern storage: several separate places (shelves for food, drinks, potions, gear; the attic), see GameData.STORAGES.
## Every place is a grid of cells: `surfaces` levels (the middle shelf and the floor plank), each `cols` x `rows`.
## Every item has a shape (GameData.item_size, w x h cells) and takes those cells; items never overlap.
## A piece can be turned by 90 degrees ("r": true), then it takes h x w cells.
## Counts {item id: n} are kept for the rest of the game; `layout` says where every piece lies.

const GameData := preload("res://scripts/game_data.gd")

var items: Dictionary = {}
## place id -> Array of pieces {"id": item id, "uid": unique number, "s": surface, "x": column, "y": row (0 = top), "r": turned}.
var layout: Dictionary = {}
var _next_uid := 1
## piece uid -> where it came from: {"c": what it cost the keeper in gold, "k": "buy" | "craft" | "free"}.
var origins: Dictionary = {}


func clear() -> void:
	items.clear()
	layout.clear()
	origins.clear()


func count(item_id: String) -> int:
	return items.get(item_id, 0)


## Id of the storage place where this item is kept.
static func place_of(item_id: String) -> String:
	return GameData.storage_of_category(GameData.ITEMS[item_id]["cat"])


static func grid_of(place_id: String) -> Dictionary:
	var p: Dictionary = GameData.STORAGES[place_id]
	return {"cols": p["cols"], "rows": p["rows"], "surfaces": p.get("surfaces", 2)}


func pieces(place_id: String) -> Array:
	if not layout.has(place_id):
		layout[place_id] = []
	return layout[place_id]


## Cells a piece takes (w x h), turned or not.
static func size_of(item_id: String, turned: bool = false) -> Vector2i:
	var sz := GameData.item_size(item_id)
	return Vector2i(sz.y, sz.x) if turned else sz


static func piece_size(p: Dictionary) -> Vector2i:
	return size_of(p["id"], p.get("r", false))


## Cells taken in this place.
func used(place_id: String) -> int:
	var n := 0
	for p in pieces(place_id):
		var sz := GameData.item_size(p["id"])
		n += sz.x * sz.y
	return n


## All cells of this place.
func capacity(place_id: String) -> int:
	var g := grid_of(place_id)
	return g["cols"] * g["rows"] * g["surfaces"]


func free_space(place_id: String) -> int:
	return maxi(0, capacity(place_id) - used(place_id))


## True if an item of this shape can lie at (s, x, y) among `list` (piece number `ignore` does not count).
static func fits(place_id: String, list: Array, item_id: String, s: int, x: int, y: int, ignore: int = -1, turned: bool = false) -> bool:
	var g := grid_of(place_id)
	var sz := size_of(item_id, turned)
	if s < 0 or s >= g["surfaces"] or x < 0 or y < 0 or x + sz.x > g["cols"] or y + sz.y > g["rows"]:
		return false
	for i in list.size():
		if i == ignore:
			continue
		var p: Dictionary = list[i]
		if p["s"] != s:
			continue
		var psz := piece_size(p)
		if x < p["x"] + psz.x and p["x"] < x + sz.x and y < p["y"] + psz.y and p["y"] < y + sz.y:
			return false
	return true


## First free spot for this item: upper shelf first, from the bottom row up (things stand on the shelf), left to right.
## Standing up is tried first; only if there is no room the item is laid on its side.
static func find_spot(place_id: String, list: Array, item_id: String) -> Dictionary:
	var g := grid_of(place_id)
	var base := GameData.item_size(item_id)
	for turned in ([false, true] if base.x != base.y else [false]):
		var sz := size_of(item_id, turned)
		for s in g["surfaces"]:
			for y in range(g["rows"] - sz.y, -1, -1):
				for x in g["cols"] - sz.x + 1:
					if fits(place_id, list, item_id, s, x, y, -1, turned):
						return {"id": item_id, "s": s, "x": x, "y": y, "r": turned}
	return {}


static func _bigger_first(a: String, b: String) -> bool:
	var sa := GameData.item_size(a)
	var sb := GameData.item_size(b)
	if sa.x * sa.y != sb.x * sb.y:
		return sa.x * sa.y > sb.x * sb.y
	if sa.y != sb.y:
		return sa.y > sb.y
	return a < b


## Lays these pieces ({"id", "uid"}) out from scratch, biggest first. Returns the new pieces, or [] if they do not all fit.
static func pack(place_id: String, entries: Array) -> Array:
	var order := entries.duplicate()
	order.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return _bigger_first(a["id"], b["id"]))
	var list: Array = []
	for e in order:
		var spot := find_spot(place_id, list, e["id"])
		if spot.is_empty():
			return []
		spot["uid"] = e.get("uid", 0)
		list.append(spot)
	return list


## Where these new items would go: the current pieces stay, new ones take free spots; if that does not work,
## everything is laid out anew. Returns the full new list of pieces, or [] if they cannot fit at all.
func plan_add(place_id: String, new_ids: Array) -> Array:
	var list: Array = pieces(place_id).duplicate(true)
	var ordered := new_ids.duplicate()
	ordered.sort_custom(_bigger_first)
	var ok := true
	for id in ordered:
		var spot := find_spot(place_id, list, id)
		if spot.is_empty():
			ok = false
			break
		spot["uid"] = 0
		list.append(spot)
	if ok:
		return list
	var entries: Array = []
	for p in pieces(place_id):
		entries.append({"id": p["id"], "uid": p["uid"]})
	for id in new_ids:
		entries.append({"id": id, "uid": 0})
	return pack(place_id, entries)


## True if n more pieces of this item fit into its storage place.
func can_fit(item_id: String, n: int = 1) -> bool:
	var ids: Array = []
	for i in n:
		ids.append(item_id)
	return not plan_add(place_of(item_id), ids).is_empty()


## True if a whole order {item: n} fits (every place checked on its own).
func can_fit_order(order: Dictionary) -> bool:
	var by_place := {}
	for id in order:
		var place := place_of(id)
		if not by_place.has(place):
			by_place[place] = []
		for i in int(order[id]):
			by_place[place].append(id)
	for place in by_place:
		if not by_place[place].is_empty() and plan_add(place, by_place[place]).is_empty():
			return false
	return true


## Puts one piece into its storage place. Returns false (and changes nothing) if it does not fit.
## origin: what the piece cost the keeper, {"c": gold, "k": "buy" | "craft" | "free"} (empty = got it for free).
func add(item_id: String, origin: Dictionary = {}) -> bool:
	var place := place_of(item_id)
	var list := plan_add(place, [item_id])
	if list.is_empty():
		return false
	for p in list:
		if p["uid"] == 0:
			p["uid"] = _next_uid
			origins[_next_uid] = {"c": int(origin.get("c", 0)), "k": origin.get("k", "free")}
			_next_uid += 1
	layout[place] = list
	items[item_id] = count(item_id) + 1
	return true


## Removes one piece of this item (the one put in last). Returns false if there is none.
func take(item_id: String) -> bool:
	return not take_piece(item_id).is_empty()


## Removes one piece of this item (the one put in last) and returns where it came from
## ({"c": gold, "k": kind}), or {} if there is none.
func take_piece(item_id: String) -> Dictionary:
	if count(item_id) <= 0:
		return {}
	var origin := {"c": 0, "k": "free"}
	var list := pieces(place_of(item_id))
	for i in range(list.size() - 1, -1, -1):
		if list[i]["id"] == item_id:
			origin = origins.get(list[i]["uid"], origin)
			origins.erase(list[i]["uid"])
			list.remove_at(i)
			break
	items[item_id] -= 1
	if items[item_id] <= 0:
		items.erase(item_id)
	return origin


## Removes the piece with this uid (from any place) and returns where it came from, or {} if there is none.
func take_uid(uid: int) -> Dictionary:
	for place_id in layout:
		var list: Array = layout[place_id]
		for i in list.size():
			if list[i]["uid"] == uid:
				var item_id: String = list[i]["id"]
				var origin: Dictionary = origins.get(uid, {"c": 0, "k": "free"})
				origins.erase(uid)
				list.remove_at(i)
				items[item_id] = count(item_id) - 1
				if items[item_id] <= 0:
					items.erase(item_id)
				return origin
	return {}


## Item id of the piece with this uid ("" if there is none).
func id_of_uid(uid: int) -> String:
	for place_id in layout:
		for p in layout[place_id]:
			if p["uid"] == uid:
				return p["id"]
	return ""


## Where the piece with this uid came from: {"c": gold, "k": kind} ({} if unknown).
func origin_of(uid: int) -> Dictionary:
	return origins.get(uid, {})


## Origins of all pieces of this item in storage.
func origins_of(item_id: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for p in pieces(place_of(item_id)):
		if p["id"] == item_id:
			result.append(origins.get(p["uid"], {"c": 0, "k": "free"}))
	return result


## Moves the piece with this uid to (s, x, y), turned or not. Returns false if it does not fit there.
func move(place_id: String, uid: int, s: int, x: int, y: int, turned: bool = false) -> bool:
	var list := pieces(place_id)
	var index := -1
	for i in list.size():
		if list[i]["uid"] == uid:
			index = i
	if index < 0 or not fits(place_id, list, list[index]["id"], s, x, y, index, turned):
		return false
	list[index]["r"] = turned
	list[index]["s"] = s
	list[index]["x"] = x
	list[index]["y"] = y
	return true


## Lays out a place tightly (biggest items first). Returns false if it could not (then nothing changes).
func tidy(place_id: String) -> bool:
	var entries: Array = []
	for p in pieces(place_id):
		entries.append({"id": p["id"], "uid": p["uid"]})
	var list := pack(place_id, entries)
	if list.is_empty() and not entries.is_empty():
		return false
	layout[place_id] = list
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
	return {"items": items.duplicate(), "layout": layout.duplicate(true), "uid": _next_uid, "origins": origins.duplicate(true)}


func restore(saved: Dictionary) -> void:
	items = saved["items"].duplicate()
	layout = saved["layout"].duplicate(true)
	_next_uid = saved.get("uid", _next_uid)
	origins = saved.get("origins", {}).duplicate(true)
