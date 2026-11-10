extends RefCounted
## The tavern storage: several places (4 shelves under the counter, the attic), see GameData.STORAGES. Any item can lie
## in any place that is built (2026-11-10: no categories); a new piece goes where the same item already lies, else to
## the first built place with room (resources try the attic first). Places not built yet are "locked" (no open cells).
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
## Grid sizes changed by the tavern upgrades (set by GameState.apply_upgrades): place id -> {"cols", "rows", "top"}.
## "top": per level, the first open row (rows above it are closed: the shelf is not built that high yet).
## "locked": true = the place is not built yet (no open cells at all).
static var grid_override: Dictionary = {}


func clear() -> void:
	items.clear()
	layout.clear()
	origins.clear()


func count(item_id: String) -> int:
	return items.get(item_id, 0)


## Id of the place where a piece of this item lies ("" if there is none).
func place_of(item_id: String) -> String:
	for place_id in layout:
		for p in layout[place_id]:
			if p["id"] == item_id:
				return place_id
	return ""


## True if this place is built (the shelves and the attic open with the upgrades).
static func is_open(place_id: String) -> bool:
	return not grid_override.get(place_id, {}).get("locked", false)


## Places that are built, in the order of GameData.STORAGES.
static func open_places() -> Array:
	var result: Array = []
	for place_id in GameData.STORAGES:
		if is_open(place_id):
			result.append(place_id)
	return result


## Where a new piece of this item is tried, in order: places that already hold it, then the other built places
## (resources: the attic before the shelves; everything else: the shelves before the attic).
func places_for(item_id: String) -> Array:
	var holding: Array = []
	var rest: Array = []
	for place_id in open_places():
		var has_it := false
		for p in pieces(place_id):
			if p["id"] == item_id:
				has_it = true
				break
		(holding if has_it else rest).append(place_id)
	if rest.has("attic"):
		rest.erase("attic")
		if GameData.ITEMS[item_id]["cat"] == "resource":
			rest.push_front("attic")
		else:
			rest.append("attic")
	return holding + rest


## Grid of a place: cols, rows, surfaces (levels) and "top" (first open row of every level).
static func grid_of(place_id: String) -> Dictionary:
	var p: Dictionary = GameData.STORAGES[place_id]
	var g := {"cols": p["cols"], "rows": p["rows"], "surfaces": p.get("surfaces", 2)}
	var o: Dictionary = grid_override.get(place_id, {})
	for key in o:
		g[key] = o[key]
	if g.get("locked", false):
		var shut: Array = []
		for s in g["surfaces"]:
			shut.append(g["rows"])
		g["top"] = shut
	elif not g.has("top"):
		var top: Array = []
		for s in g["surfaces"]:
			top.append(0)
		g["top"] = top
	return g


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


## All open cells of this place.
func capacity(place_id: String) -> int:
	var g := grid_of(place_id)
	var n := 0
	for s in g["surfaces"]:
		n += g["cols"] * (g["rows"] - int(g["top"][s]))
	return n


func free_space(place_id: String) -> int:
	return maxi(0, capacity(place_id) - used(place_id))


## Free cells in all built places together.
func free_total() -> int:
	var n := 0
	for place_id in open_places():
		n += free_space(place_id)
	return n


## Open cells in all built places together.
func capacity_total() -> int:
	var n := 0
	for place_id in open_places():
		n += capacity(place_id)
	return n


func used_total() -> int:
	var n := 0
	for place_id in layout:
		n += used(place_id)
	return n


## True if an item of this shape can lie at (s, x, y) among `list` (piece number `ignore` does not count).
static func fits(place_id: String, list: Array, item_id: String, s: int, x: int, y: int, ignore: int = -1, turned: bool = false) -> bool:
	var g := grid_of(place_id)
	var sz := size_of(item_id, turned)
	if s < 0 or s >= g["surfaces"] or x < 0 or y < int(g["top"][s]) or x + sz.x > g["cols"] or y + sz.y > g["rows"]:
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
	var cols: int = g["cols"]
	var rows: int = g["rows"]
	var surfaces: int = g["surfaces"]
	# Occupancy map of all cells, built once (checking every piece for every cell was far too slow).
	var occ := PackedByteArray()
	occ.resize(cols * rows * surfaces)
	occ.fill(0)
	for p in list:
		var psz := piece_size(p)
		var ps: int = p["s"]
		var px: int = p["x"]
		var py: int = p["y"]
		for yy in range(maxi(0, py), mini(rows, py + psz.y)):
			for xx in range(maxi(0, px), mini(cols, px + psz.x)):
				occ[(ps * rows + yy) * cols + xx] = 1
	var base := GameData.item_size(item_id)
	for turned in ([false, true] if base.x != base.y else [false]):
		var sz := size_of(item_id, turned)
		for s in surfaces:
			for y in range(rows - sz.y, int(g["top"][s]) - 1, -1):
				for x in cols - sz.x + 1:
					var is_free := true
					for yy in range(y, y + sz.y):
						var row_start := (s * rows + yy) * cols
						for xx in range(x, x + sz.x):
							if occ[row_start + xx] != 0:
								is_free = false
								break
						if not is_free:
							break
					if is_free:
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


## Where these new items would go in all places: {place id: full new list of its pieces} for every place that
## changes (new pieces have uid 0), or {} if they cannot all fit. Every piece first takes a free spot (places from
## places_for); if there is none anywhere, a place is laid out anew with it.
func plan_pieces(new_ids: Array) -> Dictionary:
	var lists := {}
	var ordered := new_ids.duplicate()
	ordered.sort_custom(_bigger_first)
	for id in ordered:
		var order := places_for(id)
		var placed := false
		for place_id in order:
			if not lists.has(place_id):
				lists[place_id] = pieces(place_id).duplicate(true)
			var spot := find_spot(place_id, lists[place_id], id)
			if not spot.is_empty():
				spot["uid"] = 0
				lists[place_id].append(spot)
				placed = true
				break
		if not placed:
			for place_id in order:
				var entries: Array = []
				for p in lists[place_id]:
					entries.append({"id": p["id"], "uid": p["uid"]})
				entries.append({"id": id, "uid": 0})
				var packed := pack(place_id, entries)
				if not packed.is_empty():
					lists[place_id] = packed
					placed = true
					break
		if not placed:
			return {}
	return lists


## True if n more pieces of this item fit into the storage.
func can_fit(item_id: String, n: int = 1) -> bool:
	var ids: Array = []
	for i in n:
		ids.append(item_id)
	return ids.is_empty() or not plan_pieces(ids).is_empty()


## True if a whole order {item: n} fits into the storage at once.
func can_fit_order(order: Dictionary) -> bool:
	var ids: Array = []
	for id in order:
		for i in int(order[id]):
			ids.append(id)
	return ids.is_empty() or not plan_pieces(ids).is_empty()


## Puts one piece into the storage. Returns false (and changes nothing) if it does not fit.
## origin: what the piece cost the keeper, {"c": gold, "k": "buy" | "craft" | "free", "q": quality (crafted only)}
## (empty = got it for free).
func add(item_id: String, origin: Dictionary = {}) -> bool:
	var lists := plan_pieces([item_id])
	if lists.is_empty():
		return false
	for place in lists:
		for p in lists[place]:
			if p["uid"] == 0:
				p["uid"] = _next_uid
				origins[_next_uid] = {"c": int(origin.get("c", 0)), "k": origin.get("k", "free")}
				if origin.has("q"):
					origins[_next_uid]["q"] = int(origin["q"])  # quality of a brewed / cooked piece (GameData.QUALITY)
				_next_uid += 1
		layout[place] = lists[place]
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
	# The newest piece (biggest uid) of this item, wherever it lies.
	var best_place := ""
	var best_i := -1
	for place_id in layout:
		var list: Array = layout[place_id]
		for i in list.size():
			if list[i]["id"] == item_id and (best_i < 0 or int(list[i]["uid"]) > int(layout[best_place][best_i]["uid"])):
				best_place = place_id
				best_i = i
	if best_i >= 0:
		var list: Array = layout[best_place]
		origin = origins.get(list[best_i]["uid"], origin)
		origins.erase(list[best_i]["uid"])
		list.remove_at(best_i)
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
	for place_id in layout:
		for p in layout[place_id]:
			if p["id"] == item_id:
				result.append(origins.get(p["uid"], {"c": 0, "k": "free"}))
	return result


## Moves the piece with this uid to (s, x, y) of place_id, turned or not; the piece may come from another place.
## Returns false if it does not fit there.
func move(place_id: String, uid: int, s: int, x: int, y: int, turned: bool = false) -> bool:
	var list := pieces(place_id)
	var index := -1
	for i in list.size():
		if list[i]["uid"] == uid:
			index = i
	if index < 0:
		# From another place: it must fit among the pieces here, then it moves over.
		for other in layout:
			if other == place_id:
				continue
			var from: Array = layout[other]
			for i in from.size():
				if from[i]["uid"] == uid:
					if not is_open(place_id) or not fits(place_id, list, from[i]["id"], s, x, y, -1, turned):
						return false
					var p: Dictionary = from[i]
					from.remove_at(i)
					p["r"] = turned
					p["s"] = s
					p["x"] = x
					p["y"] = y
					list.append(p)
					return true
		return false
	if not fits(place_id, list, list[index]["id"], s, x, y, index, turned):
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


## Item ids lying in one storage place, in the order of GameData.ITEMS.
func ids_in_place(place_id: String) -> Array[String]:
	var here := {}
	for p in pieces(place_id):
		here[p["id"]] = true
	var result: Array[String] = []
	for id in GameData.ITEMS:
		if here.has(id):
			result.append(id)
	return result


## How many pieces of this item lie in one place.
func count_in(place_id: String, item_id: String) -> int:
	var n := 0
	for p in pieces(place_id):
		if p["id"] == item_id:
			n += 1
	return n


func snapshot() -> Dictionary:
	return {"items": items.duplicate(), "layout": layout.duplicate(true), "uid": _next_uid, "origins": origins.duplicate(true)}


func restore(saved: Dictionary) -> void:
	items = saved["items"].duplicate()
	layout = saved["layout"].duplicate(true)
	_next_uid = saved.get("uid", _next_uid)
	origins = saved.get("origins", {}).duplicate(true)
