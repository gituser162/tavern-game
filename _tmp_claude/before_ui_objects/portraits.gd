extends RefCounted
## Catalogue of visitor portraits in assets/portraits/.
## File name = <group>_<m|f>_<nn>.png, for example peasant_f_01.png or hero_tank_m_01.png.
## Groups: customer type ids (peasant, reveler, herbalist, merchant, mage) and hero_<class id>.
## To add a face just drop a PNG with such a name into the folder: no code changes needed.
## Files that do not follow the pattern (portrait_01.png ...) are used only as a fallback.

const DIR := "res://assets/portraits/"

static var _groups: Dictionary = {}   # group -> Array of {"path", "gender"}
static var _all: Array = []           # every portrait, fallback when a group has none
static var _scanned := false


static func _scan() -> void:
	_scanned = true
	_groups.clear()
	_all.clear()
	var seen := {}
	for f in DirAccess.get_files_at(DIR):
		# In an exported game the folder lists "x.png.import" instead of "x.png".
		var file := f.trim_suffix(".import").trim_suffix(".remap")
		if not file.ends_with(".png") or seen.has(file):
			continue
		seen[file] = true
		var base := file.get_basename()
		var parts := base.split("_")
		var entry := {"path": DIR + file, "gender": ""}
		_all.append(entry)
		# <group...>_<m|f>_<nn>
		var n := parts.size()
		if n >= 3 and parts[n - 1].is_valid_int() and (parts[n - 2] == "m" or parts[n - 2] == "f"):
			entry["gender"] = parts[n - 2]
			var group := "_".join(parts.slice(0, n - 2))
			if not _groups.has(group):
				_groups[group] = []
			_groups[group].append(entry)


## Picks a portrait of the group. gender "" = any. avoid = paths already taken (used only if possible).
## Returns {"path", "gender"}; gender may be "" for fallback pictures. {} if the folder is empty.
static func pick(group: String, gender: String = "", avoid: Array = []) -> Dictionary:
	if not _scanned:
		_scan()
	var pool: Array = _groups.get(group, [])
	if gender != "":
		var g := pool.filter(func(e): return e["gender"] == gender)
		if not g.is_empty():
			pool = g
	if pool.is_empty():
		pool = _all
	if pool.is_empty():
		return {}
	var fresh := pool.filter(func(e): return not e["path"] in avoid)
	if not fresh.is_empty():
		pool = fresh
	return pool[randi() % pool.size()]
