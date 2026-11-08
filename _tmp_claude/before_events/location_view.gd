extends Control
## Full-screen location window (Ліс, Кладовище...): the location background with the resources lying on it.
## The player clicks a resource to gather it (GameState.gather), "Повернутися" goes back to the tavern.
## Shows itself while GameState.trip is not empty. Call refresh() whenever the game state changes.

const GameData := preload("res://scripts/game_data.gd")

const BG_SIZE := Vector2(320, 180)
## Size of a resource on the location, in background pixels.
const NODE_SIZE := 14.0
const GOLD := Color("f2c14e")
const TEXT := Color("eadbc8")
const MUTED := Color("b8a48c")

var _bg: TextureRect
var _field: Control
var _rain: Control
var _title: Label
var _status: RichTextLabel
var _hint: Label
var _event_panel: PanelContainer
var _event_title: Label
var _event_text: Label
var _event_button: Button
var _buttons: Array[TextureButton] = []
## The trip nodes the buttons were made for (same Array object = same trip).
var _shown_nodes: Array = []
var _message: String = ""
var _time: float = 0.0
var _drops: Array[Vector3] = []


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false

	_bg = TextureRect.new()
	_bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_bg.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(_bg)

	_field = Control.new()
	_field.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_field.mouse_filter = Control.MOUSE_FILTER_PASS
	_field.draw.connect(_draw_field)
	_field.resized.connect(_layout_nodes)
	add_child(_field)

	_rain = Control.new()
	_rain.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_rain.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rain.draw.connect(_draw_rain)
	add_child(_rain)

	# Top bar: location name, what was gathered, back button.
	var top := PanelContainer.new()
	top.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	top.add_theme_stylebox_override("panel", _style(Color(0.1, 0.07, 0.04, 0.9), 0))
	add_child(top)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	top.add_child(row)
	_title = Label.new()
	_title.add_theme_font_size_override("font_size", 22)
	_title.add_theme_color_override("font_color", GOLD)
	row.add_child(_title)
	_status = RichTextLabel.new()
	_status.bbcode_enabled = true
	_status.fit_content = true
	_status.scroll_active = false
	_status.autowrap_mode = TextServer.AUTOWRAP_OFF
	_status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_status.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_status.add_theme_font_size_override("normal_font_size", 15)
	_status.add_theme_color_override("default_color", TEXT)
	row.add_child(_status)
	var back := Button.new()
	back.text = "Повернутися в таверну (Esc)"
	back.custom_minimum_size = Vector2(0, 36)
	back.pressed.connect(GameState.leave_location)
	row.add_child(back)

	# Bottom hint.
	var bottom := PanelContainer.new()
	bottom.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	bottom.grow_vertical = Control.GROW_DIRECTION_BEGIN
	bottom.add_theme_stylebox_override("panel", _style(Color(0.1, 0.07, 0.04, 0.8), 0))
	add_child(bottom)
	_hint = Label.new()
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.add_theme_font_size_override("font_size", 15)
	_hint.add_theme_color_override("font_color", MUTED)
	bottom.add_child(_hint)

	# Event message in the middle of the screen.
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	_event_panel = PanelContainer.new()
	_event_panel.custom_minimum_size = Vector2(460, 0)
	_event_panel.add_theme_stylebox_override("panel", _style(Color(0.15, 0.1, 0.07, 0.96), 10))
	center.add_child(_event_panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	_event_panel.add_child(box)
	_event_title = Label.new()
	_event_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_event_title.add_theme_font_size_override("font_size", 24)
	_event_title.add_theme_color_override("font_color", GOLD)
	box.add_child(_event_title)
	_event_text = Label.new()
	_event_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_event_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_event_text.add_theme_font_size_override("font_size", 16)
	_event_text.add_theme_color_override("font_color", TEXT)
	box.add_child(_event_text)
	_event_button = Button.new()
	_event_button.custom_minimum_size = Vector2(0, 38)
	_event_button.pressed.connect(_on_event_button)
	box.add_child(_event_button)


func _style(color: Color, radius: int) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = color
	sb.set_corner_radius_all(radius)
	sb.set_content_margin_all(12)
	return sb


func refresh() -> void:
	var trip: Dictionary = GameState.trip
	visible = not trip.is_empty()
	set_process(visible)
	if not visible:
		_shown_nodes = []
		_clear_buttons()
		return
	var loc: Dictionary = GameData.LOCATIONS[trip["location"]]
	if not is_same(_shown_nodes, trip["nodes"]):
		_start_trip(trip, loc)
	for i in mini(_buttons.size(), trip["nodes"].size()):
		if trip["nodes"][i]["taken"] and not _buttons[i].disabled:
			_buttons[i].hide()  # taken without a click (nothing to animate)
	_title.text = loc["name"]
	var parts: PackedStringArray = []
	var found: Dictionary = trip["found"]
	parts.append("[color=#b8a48c]Зібрано:[/color] " + (_counts_bbcode(found) if not found.is_empty() else "нічого"))
	var left := 0
	for node in trip["nodes"]:
		if not node["taken"]:
			left += 1
	if not trip["nodes"].is_empty():
		parts.append("[color=#b8a48c]Лишилось:[/color] %d" % left)
	var places := {}
	for node in trip["nodes"]:
		places[GameState.storage.place_of(node["item"])] = true
	for place_id in places:
		parts.append("[color=#b8a48c]%s:[/color] %d / %d" % [GameData.STORAGES[place_id]["name"], GameState.storage.used(place_id), GameState.storage.capacity(place_id)])
	if _message != "":
		parts.append("[color=#e08a7a]%s[/color]" % _message)
	_status.text = "     ".join(parts)
	if _expelled():
		_hint.text = "Похід зірвано. Повертайся в таверну."
	elif left > 0:
		_hint.text = "Натисни на ресурс, щоб зібрати його. Що не збереш, залишиться тут."
	else:
		_hint.text = "Тут більше нічого немає. Можна повертатися в таверну."


func _start_trip(trip: Dictionary, loc: Dictionary) -> void:
	_shown_nodes = trip["nodes"]
	_message = ""
	_bg.texture = load(loc["bg"]) if ResourceLoader.exists(loc.get("bg", "")) else null
	_clear_buttons()
	for i in trip["nodes"].size():
		var item: String = trip["nodes"][i]["item"]
		var b := TextureButton.new()
		b.texture_normal = GameData.icon_texture(item)
		b.ignore_texture_size = true
		b.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
		b.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		b.tooltip_text = "%s\nНатисни, щоб зібрати" % GameData.ITEMS[item]["name"]
		b.pivot_offset = Vector2.ZERO
		b.mouse_entered.connect(func(): if not b.disabled: b.modulate = Color(1.35, 1.3, 1.1))
		b.mouse_exited.connect(func(): if not b.disabled: b.modulate = Color.WHITE)
		b.pressed.connect(_on_node_pressed.bind(i))
		_field.add_child(b)
		_buttons.append(b)
	_layout_nodes()
	var event: Dictionary = GameData.LOCATION_EVENTS.get(trip["event"], {})
	_event_panel.visible = not event.is_empty()
	if not event.is_empty():
		_event_title.text = event["name"]
		_event_text.text = trip.get("event_text", event["text"])
		_event_button.text = "Тікати в таверну" if _expelled() else "Збирати!"
	_drops.clear()
	if _is_raining():
		for i in 140:
			_drops.append(Vector3(randf(), randf(), randf_range(0.6, 1.4)))


func _clear_buttons() -> void:
	for b in _buttons:
		b.queue_free()
	_buttons.clear()


## Background pixel -> screen position (the background covers the window keeping its aspect).
func _bg_scale() -> float:
	return maxf(size.x / BG_SIZE.x, size.y / BG_SIZE.y)


func _to_screen(p: Vector2) -> Vector2:
	var s := _bg_scale()
	return (size - BG_SIZE * s) / 2.0 + p * s


func _layout_nodes() -> void:
	if GameState.trip.is_empty():
		return
	var nodes: Array = GameState.trip["nodes"]
	var s := _bg_scale() * NODE_SIZE
	for i in mini(_buttons.size(), nodes.size()):
		var b := _buttons[i]
		b.size = Vector2(s, s)
		# The spot is where the resource touches the ground (bottom centre).
		b.position = _to_screen(nodes[i]["spot"]) - Vector2(s / 2.0, s * 0.9)
		b.visible = not nodes[i]["taken"]
	_field.queue_redraw()


func _on_node_pressed(index: int) -> void:
	var item: String = GameState.trip["nodes"][index]["item"]
	if not GameState.gather(index):
		_message = "Немає місця: %s заповнене" % GameData.storage_name_of(item)
		refresh()
		return
	_message = ""
	var b := _buttons[index]
	b.disabled = true
	var tw := b.create_tween().set_parallel()
	tw.tween_property(b, "position:y", b.position.y - b.size.y * 0.8, 0.35)
	tw.tween_property(b, "modulate:a", 0.0, 0.35)
	tw.chain().tween_callback(b.hide)
	refresh()


func _on_event_button() -> void:
	if _expelled():
		GameState.leave_location()
	else:
		_event_panel.visible = false


## The current location's "events" entry for the event that happened ({} if none).
func _event_entry() -> Dictionary:
	var trip: Dictionary = GameState.trip
	if trip.is_empty():
		return {}
	for e in GameData.LOCATIONS[trip["location"]].get("events", []):
		if e["id"] == trip["event"]:
			return e
	return {}


func _expelled() -> bool:
	return GameData.LOCATION_EVENTS.get(GameState.trip.get("event", ""), {}).get("effect", "") == "expel"


func _is_raining() -> bool:
	return GameData.LOCATION_EVENTS.get(GameState.trip.get("event", ""), {}).get("effect", "") == "loot_mult"


func _unhandled_input(event: InputEvent) -> void:
	if visible and event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		GameState.leave_location()
		get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	_time += delta
	_field.queue_redraw()
	if _is_raining():
		_rain.queue_redraw()


## Shadows and a soft glow under the resources; glowing eyes in the bushes when a wild animal attacks.
func _draw_field() -> void:
	if GameState.trip.is_empty():
		return
	var s := _bg_scale()
	if _expelled():
		_field.draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, 0.45))
		var entry := _event_entry()
		var eye_color := Color(entry.get("eyes_color", "ffcc33"))
		if fmod(_time, 3.0) > 0.15:  # blink
			for p in entry.get("eyes", []):
				_field.draw_rect(Rect2(_to_screen(Vector2(p[0], p[1])), Vector2(s * 2, s)), eye_color)
		return
	var nodes: Array = GameState.trip["nodes"]
	for i in nodes.size():
		if nodes[i]["taken"]:
			continue
		var c := _to_screen(nodes[i]["spot"])
		var pulse := 0.5 + 0.5 * sin(_time * 3.0 + i * 1.7)
		_field.draw_set_transform(c, 0.0, Vector2(1.0, 0.4))
		_field.draw_circle(Vector2.ZERO, NODE_SIZE * s * 0.55, Color(1.0, 0.95, 0.6, 0.12 + 0.12 * pulse))
		_field.draw_circle(Vector2.ZERO, NODE_SIZE * s * 0.38, Color(0, 0, 0, 0.35))
	_field.draw_set_transform(Vector2.ZERO)


## Magic rain: violet-blue streaks with sparkles, drawn over the location.
func _draw_rain() -> void:
	if not _is_raining():
		return
	_rain.draw_rect(Rect2(Vector2.ZERO, size), Color(0.35, 0.3, 0.7, 0.12))
	var s := _bg_scale()
	for d in _drops:
		var y := fmod(d.y + _time * 0.6 * d.z, 1.0) * size.y
		var x := fmod(d.x * size.x - y * 0.15 + size.x, size.x)
		var col := Color(0.7, 0.75, 1.0, 0.55) if d.z < 1.1 else Color(0.9, 0.7, 1.0, 0.7)
		_rain.draw_rect(Rect2(Vector2(x, y), Vector2(s * 0.6, s * 4 * d.z)), col)
		if fmod(d.x * 97.0 + _time, 1.0) < 0.08:
			_rain.draw_rect(Rect2(Vector2(x - s, y + s * 4 * d.z), Vector2(s * 2.5, s * 0.6)), Color(1, 1, 1, 0.8))


func _counts_bbcode(counts: Dictionary) -> String:
	var parts: PackedStringArray = []
	for id in counts:
		parts.append("%s ×%d" % [GameData.icon_bbcode(id, 20), counts[id]])
	return "  ".join(parts)
