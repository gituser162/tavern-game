extends VBoxContainer
## Shows every storage place (pantry, cellar, cabinet...) as its own card:
## the name, how full it is, and one tile per item with the number of pieces.
## Hovering a tile emits hovered(item id) so the screen can show the item's description.

signal hovered(item_id: String, source: Control)

const GameData := preload("res://scripts/game_data.gd")

const CARD_BG := Color("1e140d")
const CARD_EDGE := Color("4a3424")
const TEXT := Color("eadbc8")
const MUTED := Color("8a7a6a")
const FULL := Color("e08a7a")
const TILE := 32
## How many storage cards go in one row.
const PER_ROW := 3

var _cards := {}


func _ready() -> void:
	add_theme_constant_override("separation", 6)
	var row: HBoxContainer = null
	for place_id in GameData.STORAGES:
		if row == null or row.get_child_count() >= PER_ROW:
			row = HBoxContainer.new()
			row.add_theme_constant_override("separation", 6)
			row.size_flags_vertical = Control.SIZE_EXPAND_FILL
			add_child(row)
		_cards[place_id] = _make_card(place_id, row)
	refresh()


func _make_card(place_id: String, row: Control) -> Dictionary:
	var place: Dictionary = GameData.STORAGES[place_id]
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	# Places with many kinds of items (like the attic) get a wider card.
	var kinds := 0
	for cat in place["cats"]:
		kinds += GameData.items_of(cat).size()
	panel.size_flags_stretch_ratio = maxf(1.0, kinds / 4.0)
	panel.tooltip_text = place.get("desc", "")
	var style := StyleBoxFlat.new()
	style.bg_color = CARD_BG
	style.border_color = CARD_EDGE
	style.set_border_width_all(2)
	style.set_corner_radius_all(4)
	style.set_content_margin_all(6)
	panel.add_theme_stylebox_override("panel", style)
	row.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	panel.add_child(box)
	var title := Label.new()
	title.add_theme_font_size_override("font_size", 14)
	title.mouse_filter = Control.MOUSE_FILTER_PASS
	box.add_child(title)
	# The tiles scroll inside the card, so a full storage never makes the panel taller.
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size = Vector2(0, TILE + 4)
	box.add_child(scroll)
	var tiles := HFlowContainer.new()
	tiles.add_theme_constant_override("h_separation", 3)
	tiles.add_theme_constant_override("v_separation", 3)
	tiles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(tiles)
	return {"panel": panel, "style": style, "title": title, "tiles": tiles}


func refresh() -> void:
	if _cards.is_empty():
		return
	var st = GameState.storage
	for place_id in _cards:
		var card: Dictionary = _cards[place_id]
		var place: Dictionary = GameData.STORAGES[place_id]
		var used: int = st.used(place_id)
		var cap: int = st.capacity(place_id)
		var title: Label = card["title"]
		title.text = "%s  %d/%d" % [place["name"], used, cap]
		title.add_theme_color_override("font_color", FULL if used >= cap else TEXT)
		var tiles: HFlowContainer = card["tiles"]
		for child in tiles.get_children():
			tiles.remove_child(child)
			child.queue_free()
		var ids: Array[String] = st.ids_in_place(place_id)
		if ids.is_empty():
			var empty := Label.new()
			empty.text = "порожньо"
			empty.add_theme_font_size_override("font_size", 13)
			empty.add_theme_color_override("font_color", MUTED)
			tiles.add_child(empty)
		for id in ids:
			tiles.add_child(_make_tile(id, st.count(id)))


func _make_tile(id: String, n: int) -> Control:
	var tile := PanelContainer.new()
	tile.custom_minimum_size = Vector2(TILE, TILE)
	var style := StyleBoxFlat.new()
	style.bg_color = Color("2e2016")
	style.border_color = GameData.category_color(GameData.ITEMS[id]["cat"]).darkened(0.25)
	style.border_width_bottom = 2
	style.set_corner_radius_all(3)
	tile.add_theme_stylebox_override("panel", style)
	tile.mouse_entered.connect(func() -> void: hovered.emit(id, tile))
	var icon := TextureRect.new()
	icon.texture = GameData.icon_texture(id)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tile.add_child(icon)
	var label := Label.new()
	label.text = "%d" % n
	label.add_theme_font_size_override("font_size", 12)
	label.add_theme_color_override("font_color", TEXT)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 4)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tile.add_child(label)
	return tile
