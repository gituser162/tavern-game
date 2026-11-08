extends Control
## Main screen. Builds the UI in code and redraws it whenever GameState changes.
## Layout: info panel on top, tavern background, client window in the middle,
## dialogue window on the right; at the bottom the storage grid, item info and the market.

const GameData := preload("res://scripts/game_data.gd")
const Wallet := preload("res://scripts/wallet.gd")
const ClientPortrait := preload("res://scripts/client_portrait.gd")
const StorageView := preload("res://scripts/storage_view.gd")
const LocationView := preload("res://scripts/location_view.gd")

const BACKGROUND := "res://assets/backgrounds/tavern.png"
const ALCHEMY_SPRITE := "res://assets/objects/mortar.png"
## Entrance door on the background (bg pixels, door with its stone frame).
const DOOR_RECT := Rect2i(11, 27, 37, 63)
const BG_SIZE := Vector2(320, 180)
const GOLD := Color("f2c14e")
const TEXT := Color("eadbc8")
const MUTED := Color("8a7a6a")

var _day_label: Label
var _gold_label: RichTextLabel
var _rep_button: Button
var _rep_popup: PopupPanel
var _rep_text: RichTextLabel
var _prosperity_label: Label
var _heroes_button: Button
var _heroes_popup: PopupPanel
var _heroes_text: RichTextLabel
var _actions_label: Label
var _client_title: RichTextLabel
var _client_subtitle: RichTextLabel
var _portrait: ClientPortrait
var _last_event: RichTextLabel
var _content: VBoxContainer
var _footer: VBoxContainer
var _storage_title: Label
var _storage_view: StorageView
var _item_info: RichTextLabel
## Floating item tooltip and the control it belongs to (hidden once the mouse leaves it).
var _tip: PanelContainer
var _tip_source: Control
var _side_title: Label
var _side_hint: RichTextLabel
var _log: RichTextLabel
var _log_popup: PopupPanel
## Alchemy window: covers the middle of the screen (the storage below stays usable).
var _alchemy_window: Control
var _alchemy_cards: HBoxContainer
var _alchemy_result: RichTextLabel
var _alchemy_object: Button
## Market window: opens over the middle of the screen like alchemy, the storage stays visible below.
var _location_view: LocationView
var _bg: TextureRect
## Door is a piece of the background cut out as a button; click opens the trip popup.
var _door_object: TextureButton
var _door_caption: Label
var _travel_popup: PanelContainer
var _travel_list: VBoxContainer

var _market_window: Control
var _market_cards: GridContainer
var _market_status: RichTextLabel
var _market_summary: RichTextLabel
var _market_buy: Button
var _market_clear: Button
## What the player has put in the market basket: {item id: n}. Bought all at once.
var _cart: Dictionary = {}
## Item the player is offering to the current visitor, and the customer it was chosen for.
var _offer_item: String = ""
var _offer_customer: int = -1
## Item the player gives the hero for the contract ("" = nothing).
var _hero_item: String = ""
var _info_item: String = ""


func _ready() -> void:
	_build_layout()
	GameState.changed.connect(_refresh)
	GameState.logged.connect(_on_logged)
	GameState.new_game()


# ---------- Layout ----------

func _build_layout() -> void:
	# Tavern background fills the whole screen; panels sit on top of it.
	var bg := TextureRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	bg.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	if ResourceLoader.exists(BACKGROUND):
		bg.texture = load(BACKGROUND)
	add_child(bg)
	_bg = bg

	var root := VBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 0)
	add_child(root)

	_build_info_panel(root)

	# Middle: free space (background shows through), client window, dialogue window.
	var middle_margin := _margin(16, 16, 16, 16)
	middle_margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	middle_margin.size_flags_stretch_ratio = 1.7
	root.add_child(middle_margin)
	var middle := HBoxContainer.new()
	middle.add_theme_constant_override("separation", 32)
	middle_margin.add_child(middle)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer.size_flags_stretch_ratio = 0.85
	middle.add_child(spacer)
	_build_door_object(spacer)
	_build_alchemy_object(spacer)

	var client := _panel(middle, Color(0.08, 0.05, 0.03, 0.55))
	client.get_parent().size_flags_horizontal = Control.SIZE_EXPAND_FILL
	client.get_parent().size_flags_stretch_ratio = 1.3
	_client_title = _rich_label("", 22, GOLD)
	_client_subtitle = _rich_label("", 15, TEXT)
	_portrait = ClientPortrait.new()
	_portrait.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_last_event = _rich_label("", 15, TEXT)
	client.add_child(_client_title)
	client.add_child(_client_subtitle)
	client.add_child(_portrait)
	client.add_child(_last_event)

	var dialogue := _panel(middle, Color(0.17, 0.11, 0.07, 0.92))
	dialogue.get_parent().size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dialogue.get_parent().size_flags_stretch_ratio = 1.0
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	dialogue.add_child(scroll)
	_content = VBoxContainer.new()
	_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content.add_theme_constant_override("separation", 8)
	scroll.add_child(_content)
	# Main action of the phase (open tavern, next day...) stays pinned under the scroll.
	_footer = VBoxContainer.new()
	dialogue.add_child(_footer)
	_build_alchemy_window(middle_margin)
	_build_market_window(middle_margin)

	# Bottom: storage grid on the left, item info and market on the right.
	var bottom_margin := _margin(0, 0, 0, 0)
	bottom_margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	bottom_margin.size_flags_stretch_ratio = 1.0
	bottom_margin.clip_contents = true
	root.add_child(bottom_margin)
	var bottom := HBoxContainer.new()
	bottom.add_theme_constant_override("separation", 0)
	bottom_margin.add_child(bottom)

	var store := _panel(bottom, Color(0.12, 0.08, 0.05, 0.96), 0)
	_storage_title = _label("Склад", 18, GOLD, false)
	store.add_child(_storage_title)
	_storage_view = StorageView.new()
	_storage_view.custom_minimum_size = Vector2(400, 0)
	_storage_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_storage_view.hovered.connect(_on_item_hovered)
	store.add_child(_storage_view)

	var side := _panel(bottom, Color(0.12, 0.08, 0.05, 0.96), 0)
	side.get_parent().size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var side_row := HBoxContainer.new()
	side_row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	side_row.add_theme_constant_override("separation", 14)
	side.add_child(side_row)
	var market_box := VBoxContainer.new()
	market_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	side_row.add_child(market_box)
	_side_title = _label("", 18, GOLD, false)
	market_box.add_child(_side_title)
	_side_hint = _rich_label("", 14, MUTED)
	market_box.add_child(_side_hint)

	_build_log_popup()
	_build_travel_popup()

	# Location screen (forest, graveyard...) covers the whole tavern while the keeper is away.
	_location_view = LocationView.new()
	add_child(_location_view)

	# Item description: a tooltip that follows the mouse (added last so it draws over everything).
	_build_item_tip()


func _build_info_panel(root: Control) -> void:
	var info := _panel(root, Color(0.1, 0.06, 0.04, 0.95), 0)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 14)
	info.add_child(top)
	var title := _label("Таверна «Втомлений Грифон»", 20, GOLD, false)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(title)
	_day_label = _label("", 18, TEXT, false)
	_gold_label = _rich_label("", 18, TEXT)
	_gold_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	_rep_button = Button.new()
	_rep_button.pressed.connect(_on_rep_pressed)
	_prosperity_label = _label("", 18, TEXT, false)
	_prosperity_label.mouse_filter = Control.MOUSE_FILTER_STOP
	_heroes_button = Button.new()
	_heroes_button.pressed.connect(_on_heroes_pressed)
	_actions_label = _label("", 18, TEXT, false)
	_actions_label.mouse_filter = Control.MOUSE_FILTER_STOP
	_actions_label.tooltip_text = "Особисті дії власника на день. Похід у локацію коштує %d дію, похід на ринок %d дію (далі ринок відкритий до кінця ранку). Варка зілля дій не витрачає." % [GameData.LOCATION_ACTION_COST, GameData.MARKET_ACTION_COST]
	for l in [_day_label, _gold_label, _actions_label, _rep_button, _prosperity_label, _heroes_button]:
		l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		top.add_child(l)
	var log_button := Button.new()
	log_button.text = "Журнал"
	log_button.pressed.connect(_on_log_pressed)
	top.add_child(log_button)


func _build_log_popup() -> void:
	_log_popup = PopupPanel.new()
	_log_popup.size = Vector2i(640, 420)
	var style := StyleBoxFlat.new()
	style.bg_color = Color("2a1c12")
	style.border_color = Color("6b4a2f")
	style.set_border_width_all(2)
	style.set_content_margin_all(12)
	_log_popup.add_theme_stylebox_override("panel", style)
	_log = RichTextLabel.new()
	_log.bbcode_enabled = true
	_log.scroll_following = true
	_log.add_theme_color_override("default_color", TEXT)
	_log_popup.add_child(_log)
	add_child(_log_popup)

	_heroes_popup = PopupPanel.new()
	_heroes_popup.size = Vector2i(720, 460)
	_heroes_popup.add_theme_stylebox_override("panel", style.duplicate())
	_heroes_text = RichTextLabel.new()
	_heroes_text.bbcode_enabled = true
	_heroes_text.add_theme_color_override("default_color", TEXT)
	_heroes_popup.add_child(_heroes_text)
	add_child(_heroes_popup)

	_rep_popup = PopupPanel.new()
	_rep_popup.size = Vector2i(760, 500)
	_rep_popup.add_theme_stylebox_override("panel", style.duplicate())
	_rep_text = RichTextLabel.new()
	_rep_text.bbcode_enabled = true
	_rep_text.add_theme_color_override("default_color", TEXT)
	_rep_popup.add_child(_rep_text)
	add_child(_rep_popup)


func _margin(l: int, t: int, r: int, b: int) -> MarginContainer:
	var m := MarginContainer.new()
	m.add_theme_constant_override("margin_left", l)
	m.add_theme_constant_override("margin_top", t)
	m.add_theme_constant_override("margin_right", r)
	m.add_theme_constant_override("margin_bottom", b)
	return m


func _panel(parent: Control, bg: Color, radius: int = 8) -> VBoxContainer:
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = Color("6b4a2f")
	style.set_border_width_all(2)
	style.set_corner_radius_all(radius)
	style.set_content_margin_all(12)
	panel.add_theme_stylebox_override("panel", style)
	parent.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	panel.add_child(box)
	return box


func _label(text: String, size: int = 16, color: Color = TEXT, wrap: bool = true) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	if wrap:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l


## Like _label, but understands BBCode, so it can show coin icons.
func _rich_label(text: String, size: int = 16, color: Color = TEXT) -> RichTextLabel:
	var r := RichTextLabel.new()
	r.bbcode_enabled = true
	r.fit_content = true
	r.scroll_active = false
	r.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.add_theme_font_size_override("normal_font_size", size)
	r.add_theme_font_size_override("bold_font_size", size)
	r.add_theme_color_override("default_color", color)
	r.text = text
	return r


## Button whose caption is BBCode (so prices can show coin icons).
func _button(text: String, callback: Callable, disabled: bool = false, parent: Control = null, font_size: int = 15) -> Button:
	var b := Button.new()
	b.disabled = disabled
	b.custom_minimum_size = Vector2(0, 34 + 20 * text.count("\n"))
	b.pressed.connect(callback)
	var caption := _rich_label("[center]%s[/center]" % text, font_size, MUTED if disabled else TEXT)
	caption.autowrap_mode = TextServer.AUTOWRAP_OFF
	var center := CenterContainer.new()
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.add_child(caption)
	b.add_child(center)
	(parent if parent != null else _content).add_child(b)
	return b


# ---------- Refresh ----------

func _refresh() -> void:
	_day_label.text = "День %d / %d" % [GameState.day, GameData.LAST_DAY]
	_gold_label.text = "%s  [color=#8a7a6a]мета[/color] %s" % [GameState.wallet.format(true), _m(GameData.GOAL_MONEY)]
	_actions_label.text = "Дії: %d / %d" % [GameState.actions_left, GameData.ACTIONS_PER_DAY]
	var rank: Dictionary = GameState.rep_rank()
	_rep_button.text = "%s · %d" % [rank["name"], GameState.reputation]
	var next := GameState.rep_to_next_rank()
	_rep_button.tooltip_text = "Репутація таверни: %d. " % GameState.reputation + ("До наступного рангу: %d. " % next if next > 0 else "Найвищий ранг. ") + "Натисни, щоб побачити, що відкриває репутація."
	if _rep_popup.visible:
		_rep_text.text = _rep_bbcode()
	_prosperity_label.text = "Процвітання: %d" % GameState.prosperity
	_prosperity_label.tooltip_text = "%s. Ціни в місті ×%.2f" % [GameData.prosperity_name(GameState.prosperity), GameData.prosperity_mult(GameState.prosperity)]
	if GameState.phase == GameState.Phase.SERVICE and _offer_customer != GameState.customer_index:
		_offer_customer = GameState.customer_index
		_offer_item = ""
		_hero_item = ""
	_heroes_button.text = "Герої: %d / %d" % [GameState.heroes.size(), GameState.max_heroes()]
	_heroes_button.tooltip_text = "Вільні: %d, на завданні: %d, поранені: %d. Натисни, щоб побачити всіх." % [GameState.hero_count("free"), GameState.hero_count("quest"), GameState.hero_count("injured")]
	if _heroes_popup.visible:
		_heroes_text.text = _heroes_bbcode()

	_refresh_client()
	_refresh_storage()
	_refresh_alchemy()
	_refresh_market()
	_refresh_door()
	_location_view.refresh()

	for box in [_content, _footer]:
		for child in box.get_children():
			box.remove_child(child)
			child.queue_free()
	match GameState.phase:
		GameState.Phase.MARKET:
			_show_market()
		GameState.Phase.SERVICE:
			if GameState.brawl_active:
				_show_brawl()
			elif GameState.awaiting_quest:
				_show_quest_offer()
			else:
				_show_customer()
		GameState.Phase.EVENING:
			_show_evening()
		GameState.Phase.GAME_OVER:
			_show_game_over()


func _refresh_client() -> void:
	var c: Dictionary = GameState.current_customer
	if GameState.phase == GameState.Phase.SERVICE and GameState.brawl_active:
		_portrait.customer_type = ""
		_client_title.text = GameData.BRAWL["name"]
		_client_subtitle.text = "У залі б'ються! Вирішуй, що робити."
		return
	if GameState.phase == GameState.Phase.SERVICE:
		_portrait.customer_type = c["type"]
		_client_title.text = "%s, %s   %s" % [c["name"], String(c["title"]).to_lower(), _tag_bbcode(c["tag"])]
		var sub := "Відвідувач %d з %d" % [GameState.customer_index, GameState.customers_today.size()]
		var hero := GameState.current_hero()
		if not hero.is_empty():
			sub = "Герой · %s · сума %d\n[color=#b8a48c]%s[/color]" % [sub, GameData.stats_sum(hero["stats"]), GameData.stats_text(hero["stats"], false)]
		_client_subtitle.text = sub
		return
	_portrait.customer_type = ""
	match GameState.phase:
		GameState.Phase.MARKET:
			_client_title.text = "Ранок"
			_client_subtitle.text = "Таверна ще зачинена. Вийди через двері на ринок по запаси, по ресурси в ліс чи на кладовище або звари зілля."
		GameState.Phase.EVENING:
			_client_title.text = "Вечір"
			_client_subtitle.text = "Останні гості розійшлися."
		GameState.Phase.GAME_OVER:
			_client_title.text = "Перемога!" if GameState.won else "Кінець гри"
			_client_subtitle.text = ""


func _refresh_storage() -> void:
	var st := GameState.storage
	var used := 0
	var total := 0
	for place_id in GameData.STORAGES:
		used += st.used(place_id)
		total += st.capacity(place_id)
	_storage_title.text = "Склад  ·  %d / %d місць" % [used, total]
	_storage_view.refresh()

	var controls := "[color=#b8a48c]Кожна категорія лежить у своєму сховищі з власною місткістю: комора, погріб, шафа, скриня, горище.[/color]"
	_side_title.text = "Склад"
	if GameState.phase == GameState.Phase.MARKET:
		_side_hint.text = "Товари купуються на ринку (натисни на двері таверни ліворуч). Зілля на ринку не продаються: їх вариш сам у вікні «Алхімія».\n" + controls
	else:
		var hint := controls
		if GameState.phase == GameState.Phase.SERVICE and GameState.brawl_active:
			hint = "Поки в залі бійка, торгівля стоїть.\n" + controls
		elif GameState.phase == GameState.Phase.SERVICE and not GameState.awaiting_quest:
			hint = "Відвідувач купує лише %s.\n%s" % [_tag_bbcode(GameState.current_customer["tag"]), controls]
		elif GameState.phase == GameState.Phase.SERVICE:
			hint = "Герою можна дати зілля, спорядження або магічну річ. Спорядження й магія повертаються, якщо герой виживе.\n" + controls
		_side_hint.text = hint
	_show_item_info(_info_item)


func _build_item_tip() -> void:
	_tip = PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color("1e140d")
	style.border_color = Color("8a6a45")
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	style.set_content_margin_all(10)
	_tip.add_theme_stylebox_override("panel", style)
	_tip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tip.top_level = true
	_tip.z_index = 100
	_tip.visible = false
	_item_info = _rich_label("", 14, TEXT)
	_item_info.custom_minimum_size = Vector2(300, 0)
	_tip.add_child(_item_info)
	add_child(_tip)


func _process(_delta: float) -> void:
	if _tip == null or not _tip.visible:
		return
	var mouse := get_global_mouse_position()
	if not is_instance_valid(_tip_source) or not _tip_source.is_visible_in_tree() \
			or not _tip_source.get_global_rect().has_point(mouse):
		_tip.visible = false
		_tip_source = null
		return
	_tip.reset_size()
	var screen := get_viewport_rect().size
	var pos := mouse + Vector2(18, 18)
	if pos.x + _tip.size.x > screen.x - 4:
		pos.x = mouse.x - _tip.size.x - 12
	if pos.y + _tip.size.y > screen.y - 4:
		pos.y = mouse.y - _tip.size.y - 12
	_tip.global_position = Vector2(maxf(pos.x, 4), maxf(pos.y, 4))


func _show_item_info(id: String) -> void:
	_info_item = id
	if id == "":
		_item_info.text = ""
		return
	var item: Dictionary = GameData.ITEMS[id]
	var cat: Dictionary = GameData.CATEGORIES[item["cat"]]
	var sources: PackedStringArray = []
	for src in item["sources"]:
		if src == "location" and not GameData.item_locations(id).is_empty():
			sources.append(", ".join(GameData.item_locations(id)).to_lower())
		else:
			sources.append(GameData.SOURCES[src])
	var lines: PackedStringArray = [
		"%s [b][color=#f2c14e]%s[/color][/b]" % [GameData.icon_bbcode(id, 32), item["name"]],
		"[color=#%s]%s[/color]  ·  зберігається: %s" % [cat["color"], cat["name"], GameData.storage_name_of(id)],
		"Ціна продажу сьогодні: %s" % _m(GameState.item_price(id)),
		"[i]%s[/i]" % item["desc"],
		"[color=#8a7a6a]Звідки: %s[/color]" % ", ".join(sources),
	]
	if GameData.is_brewable(id):
		lines.append("[color=#b8a48c]Рецепт:[/color] %s" % _recipe_bbcode(id))
	var used_in := GameData.used_in_recipes(id)
	if not used_in.is_empty():
		lines.append("[color=#8a7a6a]Інгредієнт для: %s[/color]" % ", ".join(used_in))
	if item.has("hero_stats"):
		var keep := "повертається, якщо герой виживе" if item["cat"] in GameData.RETURNING_CATEGORIES else "витрачається"
		lines.insert(3, "Герою на контракт: %s (%s)" % [GameData.stats_text(item["hero_stats"]), keep])
	var stock := GameState.storage.count(id)
	if stock > 0:
		lines.insert(2, "На складі: %d шт." % stock)
	_item_info.text = "\n".join(lines)


func _tag_bbcode(cat: String) -> String:
	var c: Dictionary = GameData.CATEGORIES[cat]
	return "[bgcolor=#%s][color=#1a1009] %s [/color][/bgcolor]" % [c["color"], c["tag"]]


## Roster of all heroes for the "Герої" window.
func _heroes_bbcode() -> String:
	var lines: PackedStringArray = ["[b][color=#f2c14e]Герої міста[/color][/b]  [color=#8a7a6a](приходять до таверни як відвідувачі; ті, хто на завданні або поранені, не приходять)[/color]\n"]
	if GameState.heroes.is_empty():
		lines.append("[color=#8a7a6a]Ще жоден герой не заходив до таверни.[/color]")
	for h in GameState.heroes:
		var status: String = GameData.HERO_STATUS_NAMES[h["status"]]
		match h["status"]:
			"quest":
				var back := 0
				for q in GameState.active_quests:
					if q["hero_id"] == h["id"]:
						back = q["return_day"]
				status = "[color=#e0c84a]%s: «%s», повернеться на день %d[/color]" % [status, h["quest"], back]
			"injured":
				status = "[color=#e0904a]%s, одужає на день %d[/color]" % [status, h["injured_until"]]
			_:
				status = "[color=#a8d08d]%s[/color]" % status
		lines.append("[b]%s[/b], %s  ·  %s  ·  контрактів виконано: %d" % [h["name"], GameData.HERO_CLASSES[h["class"]]["name"].to_lower(), status, h.get("done", 0)])
		lines.append("    [color=#b8a48c]%s  ·  сума %d[/color]" % [GameData.stats_text(h["stats"], false), GameData.stats_sum(h["stats"])])
	return "\n".join(lines)


## Reputation window: how to earn it and what every rank opens.
func _rep_bbcode() -> String:
	var current := GameData.rep_rank_index(GameState.reputation)
	var lines: PackedStringArray = ["[b][color=#f2c14e]Репутація таверни: %d[/color][/b]  [color=#8a7a6a](від %d до %d)[/color]" % [GameState.reputation, GameData.REP_MIN, GameData.REP_MAX]]
	lines.append("[color=#b8a48c]Росте від виконаних контрактів (легкий +%d, середній +%d, важкий +%d) і продажу «Дешево» (+%d). Падає, коли відвідувач іде невдоволений (%d), за «Здирство» (%d), коли герой повертається пораненим (%d) або гине (%d).[/color]" % [
		GameData.CONTRACT_TIERS["easy"]["rep"], GameData.CONTRACT_TIERS["medium"]["rep"], GameData.CONTRACT_TIERS["hard"]["rep"],
		GameData.PRICE_OPTIONS[0]["rep"], GameData.REP_UNHAPPY_CUSTOMER, GameData.PRICE_OPTIONS[3]["rep"], GameData.REP_HERO_INJURED, GameData.REP_HERO_DIED])
	lines.append("[color=#b8a48c]Кожне очко репутації дає %+.1f%% до шансу, що відвідувач погодиться на ціну (зараз %+d%%).[/color]\n" % [GameData.REP_SALE_BONUS_PER_POINT * 100, roundi(GameState.reputation * GameData.REP_SALE_BONUS_PER_POINT * 100)])
	for i in GameData.REP_RANKS.size():
		var rank: Dictionary = GameData.REP_RANKS[i]
		var head := "%d+  %s" % [rank["min"], rank["name"]]
		if i == current:
			head = "[color=#f2c14e][b]▶ %s  (ти тут)[/b][/color]" % head
		elif i < current:
			head = "[color=#a8d08d]✓ %s[/color]" % head
		else:
			head = "[color=#8a7a6a]%s[/color]" % head
		lines.append(head)
		var news := GameState.rank_unlocks_text(i)
		if news != "":
			lines.append("    [color=#%s]%s[/color]" % ["eadbc8" if i <= current else "8a7a6a", news])
	return "\n".join(lines)


func _contract_bbcode(q: Dictionary) -> String:
	var tier: Dictionary = GameData.CONTRACT_TIERS[q["tier"]]
	var loot := ""
	for entry in q["loot"]:
		loot += GameData.icon_bbcode(entry["item"], 18)
	var text := "[b]%s[/b]  [color=#b8a48c]%s · %d дн. · нагорода %s[/color]" % [q["title"], tier["name"].to_lower(), q["days"], _m(q["reward"])]
	if loot != "":
		text += "  [color=#8a7a6a]трофеї:[/color] " + loot
	return text


# ---------- Dialogue window ----------

func _show_market() -> void:
	_content.add_child(_label("Ранок: ринок, подорожі й алхімія", 20, GOLD))
	if GameState.town_event != "":
		var ev_name: String = GameData.FAIR["name"] if GameState.town_event == "fair" else GameData.TAX_COLLECTOR["name"]
		var col := "a8d08d" if GameState.town_event == "fair" else "e0904a"
		_content.add_child(_rich_label("[color=#%s][b]%s.[/b] %s[/color]" % [col, ev_name, GameState.town_event_text], 16))
	_show_trips_summary()
	_content.add_child(HSeparator.new())
	_content.add_child(_label("Алхімія: натисни на ступку в таверні ліворуч, щоб варити зілля. Варка дій не витрачає.", 15, MUTED))
	_content.add_child(HSeparator.new())
	_content.add_child(_label("Кожен відвідувач носить тег і купує лише товари своєї категорії."))
	_content.add_child(_label("Ціни залежать від процвітання міста: %s (%d), ×%.2f." % [GameData.prosperity_name(GameState.prosperity), GameState.prosperity, GameData.prosperity_mult(GameState.prosperity)], 15, MUTED))
	_content.add_child(HSeparator.new())
	_content.add_child(_label("Дошка контрактів", 18, GOLD))
	_content.add_child(_label("Героїв можна відправити на контракт, коли вони зайдуть до таверни. Успіх залежить від суми характеристик героя і речі, яку ти йому даси.", 14, MUTED))
	for q in GameState.quest_board:
		_content.add_child(_rich_label("• " + _contract_bbcode(q), 15))
	var locked := GameData.CONTRACTS.size() - GameState.unlocked_ids(GameData.CONTRACTS).size()
	if locked > 0:
		_content.add_child(_label("Ще %d контр. відкриється з ростом репутації." % locked, 14, MUTED))
	if not GameState.active_quests.is_empty():
		_content.add_child(_label("Герої на контрактах", 16, GOLD))
		for q in GameState.active_quests:
			_content.add_child(_rich_label("• %s: «%s», повернеться на день %d" % [q["hero"], q["title"], q["return_day"]], 15))
	_button("Відчинити таверну", GameState.open_tavern, false, _footer)


## What the dialogue window says about leaving the tavern; the choice itself is in the door popup.
func _show_trips_summary() -> void:
	_content.add_child(_label("Вихід із таверни", 18, GOLD))
	_content.add_child(_label("Натисни на двері ліворуч, щоб піти на ринок, у ліс чи на кладовище. Дій: %d з %d. У кожну локацію можна піти раз на день, перший похід на ринок коштує %d дію." % [GameState.actions_left, GameData.ACTIONS_PER_DAY, GameData.MARKET_ACTION_COST], 15, MUTED))
	if not GameState.bought_today.is_empty():
		_content.add_child(_rich_label("[color=#b8a48c]Куплено сьогодні:[/color] " + _counts_bbcode(GameState.bought_today), 15))
	var trip: Dictionary = GameState.last_trip
	if not trip.is_empty():
		var text := "[color=#b8a48c]Останній похід (%s):[/color] " % GameData.LOCATIONS[trip["location"]]["name"]
		var event: Dictionary = GameData.LOCATION_EVENTS.get(trip.get("event", ""), {})
		if event.get("effect", "") == "expel":
			text += "[color=#e08a7a]%s, довелося тікати[/color]" % event["name"].to_lower()
		else:
			if not event.is_empty():
				text += "[color=violet]%s![/color] " % event["name"]
			text += _counts_bbcode(trip["found"]) if not trip["found"].is_empty() else "нічого не зібрано"
		if not trip["left"].is_empty():
			text += "\n[color=#e08a7a]Залишено в локації:[/color] " + _counts_bbcode(trip["left"])
		_content.add_child(_rich_label(text, 15))


# ---------- Door and trip popup ----------

func _build_door_object(parent: Control) -> void:
	_door_object = TextureButton.new()
	if _bg.texture != null:
		var atlas := AtlasTexture.new()
		atlas.atlas = _bg.texture
		atlas.region = Rect2(DOOR_RECT)
		_door_object.texture_normal = atlas
	_door_object.ignore_texture_size = true
	_door_object.stretch_mode = TextureButton.STRETCH_SCALE
	_door_object.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_door_object.focus_mode = Control.FOCUS_NONE
	_door_object.pressed.connect(_toggle_travel_popup)
	parent.add_child(_door_object)
	_door_caption = _label("Вийти з таверни", 16, GOLD, false)
	_door_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_door_caption.add_theme_color_override("font_outline_color", Color.BLACK)
	_door_caption.add_theme_constant_override("outline_size", 6)
	_door_caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_door_caption.visible = false
	parent.add_child(_door_caption)
	# Same hover look as the mortar: the door lights up and the caption appears.
	_door_object.mouse_entered.connect(_on_door_hover.bind(true))
	_door_object.mouse_exited.connect(_on_door_hover.bind(false))
	_bg.resized.connect(_place_door, CONNECT_DEFERRED)
	parent.resized.connect(_place_door, CONNECT_DEFERRED)
	_place_door.call_deferred()


func _on_door_hover(inside: bool) -> void:
	var lit := inside and not _door_object.disabled
	_door_object.modulate = Color(1.35, 1.25, 0.95) if lit else Color.WHITE
	_door_caption.visible = lit


## Puts the door button exactly over the door drawn on the background (it is scaled to cover the screen).
func _place_door() -> void:
	if _door_object == null or _bg == null:
		return
	var k := maxf(_bg.size.x / BG_SIZE.x, _bg.size.y / BG_SIZE.y)
	var origin := _bg.global_position + (_bg.size - BG_SIZE * k) / 2.0
	var rect := Rect2(origin + Vector2(DOOR_RECT.position) * k, Vector2(DOOR_RECT.size) * k)
	_door_object.global_position = rect.position
	_door_object.size = rect.size
	_door_caption.size = Vector2(rect.size.x + 80, 26)
	_door_caption.global_position = Vector2(rect.position.x - 40, rect.position.y - 30)
	if _travel_popup != null:
		_travel_popup.global_position = Vector2(rect.end.x + 10, rect.position.y)


func _build_travel_popup() -> void:
	_travel_popup = PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.15, 0.1, 0.07, 0.97)
	style.border_color = Color("6b4a2f")
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	style.set_content_margin_all(12)
	_travel_popup.add_theme_stylebox_override("panel", style)
	_travel_popup.custom_minimum_size = Vector2(320, 0)
	_travel_popup.visible = false
	add_child(_travel_popup)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	_travel_popup.add_child(box)
	var header := HBoxContainer.new()
	box.add_child(header)
	var title := _label("Куди підемо?", 20, GOLD, false)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	var close := Button.new()
	close.text = "✕"
	close.tooltip_text = "Закрити (Esc)"
	close.focus_mode = Control.FOCUS_NONE
	close.pressed.connect(_close_travel_popup)
	header.add_child(close)
	_travel_list = VBoxContainer.new()
	_travel_list.add_theme_constant_override("separation", 8)
	box.add_child(_travel_list)


func _toggle_travel_popup() -> void:
	if _travel_popup.visible:
		_close_travel_popup()
		return
	if GameState.phase != GameState.Phase.MARKET:
		return
	_travel_popup.visible = true
	_place_door()
	_refresh_travel_popup()


func _close_travel_popup() -> void:
	_travel_popup.visible = false


func _refresh_door() -> void:
	var morning := GameState.phase == GameState.Phase.MARKET
	_door_object.disabled = not morning
	_door_object.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if morning else Control.CURSOR_ARROW
	_door_object.tooltip_text = "Вийти з таверни: ринок і локації" if morning else "Виходити можна лише зранку, поки таверна зачинена"
	if not morning:
		_travel_popup.visible = false
		_on_door_hover(false)
	_refresh_travel_popup()


func _refresh_travel_popup() -> void:
	if not _travel_popup.visible:
		return
	for child in _travel_list.get_children():
		_travel_list.remove_child(child)
		child.queue_free()
	_travel_list.add_child(_label("Дій: %d з %d" % [GameState.actions_left, GameData.ACTIONS_PER_DAY], 15, MUTED, false))
	var caption: String
	if GameState.market_visited:
		caption = "Ринок  [color=#b8a48c](уже оплачено)[/color]"
	else:
		caption = "Ринок  [color=#b8a48c](%d дія)[/color]" % GameData.MARKET_ACTION_COST
	var mb := _button(caption, _go_market, not GameState.can_visit_market(), _travel_list)
	mb.tooltip_text = "Їжа, напої, ресурси, спорядження героїв і магічні речі. Ціни залежать від процвітання міста.\nПерший похід за день коштує %d дію, далі ринок відкритий до кінця ранку." % GameData.MARKET_ACTION_COST
	for loc_id in GameData.LOCATIONS:
		var loc: Dictionary = GameData.LOCATIONS[loc_id]
		var icons := ""
		for entry in loc["loot"]:
			icons += GameData.icon_bbcode(entry["item"], 20)
		var note := "(%d дія)" % GameData.LOCATION_ACTION_COST
		if loc_id in GameState.closed_locations:
			note = "(закрито до завтра)"
		elif loc_id in GameState.visited_locations:
			note = "(сьогодні вже був, завтра знову)"
		var b := _button("%s  [color=#b8a48c]%s[/color]\n%s" % [loc["name"], note, icons], _go_location.bind(loc_id), not GameState.can_travel_to(loc_id), _travel_list)
		b.tooltip_text = "%s\n\n%s" % [loc["desc"], _location_tooltip(loc)]


func _go_market() -> void:
	_close_travel_popup()
	_open_market()


func _go_location(loc_id: String) -> void:
	_close_travel_popup()
	GameState.travel(loc_id)


# ---------- Market window ----------

func _build_market_window(parent: Control) -> void:
	var box := _panel(parent, Color(0.15, 0.1, 0.07, 1.0))
	_market_window = box.get_parent()
	_market_window.visible = false
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 16)
	box.add_child(header)
	var title := _label("Міський ринок", 22, GOLD, false)
	header.add_child(title)
	_market_status = _rich_label("", 15, TEXT)
	_market_status.autowrap_mode = TextServer.AUTOWRAP_OFF
	_market_status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_market_status.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	header.add_child(_market_status)
	var close := Button.new()
	close.text = "Закрити (Esc)"
	close.pressed.connect(_close_market)
	header.add_child(close)
	box.add_child(_label("Додай товари в кошик кнопками − / + і купи все разом. Покупки одразу лягають у свої сховища (склад внизу), тож купити можна лише стільки, скільки там є місця. Ресурси з лісу й кладовища та зілля тут не продаються.", 14, MUTED))
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(scroll)
	_market_cards = GridContainer.new()
	_market_cards.columns = 4
	_market_cards.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_market_cards.add_theme_constant_override("h_separation", 8)
	_market_cards.add_theme_constant_override("v_separation", 6)
	scroll.add_child(_market_cards)
	var footer := HBoxContainer.new()
	footer.add_theme_constant_override("separation", 12)
	box.add_child(footer)
	_market_summary = _rich_label("", 15, TEXT)
	_market_summary.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_market_summary.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	footer.add_child(_market_summary)
	_market_clear = Button.new()
	_market_clear.text = "Очистити кошик"
	_market_clear.custom_minimum_size = Vector2(0, 36)
	_market_clear.pressed.connect(_on_cart_clear)
	footer.add_child(_market_clear)
	_market_buy = Button.new()
	_market_buy.text = "Купити"
	_market_buy.custom_minimum_size = Vector2(140, 36)
	_market_buy.pressed.connect(_on_cart_buy)
	footer.add_child(_market_buy)


func _open_market() -> void:
	# The first visit of the day spends an action (GameState decides); then the market stays open.
	if not GameState.visit_market():
		return
	_alchemy_window.visible = false
	_market_window.visible = true
	_refresh_market()


func _close_market() -> void:
	_market_window.visible = false
	_refresh_market()


func _refresh_market() -> void:
	# The market works only in the morning: the window closes by itself when the tavern opens.
	if GameState.phase != GameState.Phase.MARKET or not GameState.market_visited:
		_market_window.visible = false
		_cart.clear()
	if not _market_window.visible:
		return
	_market_status.text = "%s  ·  [color=#b8a48c]ціни ×%.2f (%s)[/color]" % [GameState.wallet.format(true), GameData.prosperity_mult(GameState.prosperity), GameData.prosperity_name(GameState.prosperity).to_lower()]
	if GameState.town_event == "fair":
		_market_status.text += "  ·  [color=#a8d08d]ярмарок: ще −%d%%[/color]" % roundi((1.0 - GameData.FAIR["market_mult"]) * 100)
	for child in _market_cards.get_children():
		_market_cards.remove_child(child)
		child.queue_free()
	for id in GameData.ITEMS:
		if GameData.is_buyable(id):
			_market_cards.add_child(_make_market_card(id))

	var cost := GameState.order_cost(_cart)
	var pieces := 0
	for id in _cart:
		pieces += _cart[id]
	if pieces == 0:
		_market_summary.text = "[color=#8a7a6a]Кошик порожній.[/color]"
		if not GameState.bought_today.is_empty():
			_market_summary.text += "  [color=#a8d08d]Сьогодні куплено:[/color] " + _counts_bbcode(GameState.bought_today)
	else:
		var places := GameState.order_places(_cart)
		var parts: PackedStringArray = []
		for place in places:
			parts.append("%s +%d (вільно %d)" % [GameData.STORAGES[place]["name"], places[place], GameState.storage.free_space(place)])
		_market_summary.text = "У кошику %d шт. на %s, залишиться %s\n[color=#b8a48c]%s[/color]" % [pieces, _m(cost), _m(GameState.wallet.total - cost), ",  ".join(parts)]
	var problem := GameState.order_problem(_cart)
	_market_buy.disabled = problem != ""
	_market_buy.text = "Купити" if pieces == 0 else "Купити за %d" % cost
	_market_buy.tooltip_text = problem
	_market_clear.disabled = pieces == 0


## How many more pieces of this item can go into the basket (room in its storage and money left).
func _cart_room(id: String) -> int:
	var place := GameData.storage_of_category(GameData.ITEMS[id]["cat"])
	var in_cart: int = GameState.order_places(_cart).get(place, 0)
	var room := GameState.storage.free_space(place) - in_cart
	var money := GameState.wallet.total - GameState.order_cost(_cart)
	return mini(room, money / GameState.item_cost(id))


func _make_market_card(id: String) -> Control:
	var item: Dictionary = GameData.ITEMS[id]
	var in_cart: int = _cart.get(id, 0)
	var card := PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var style := StyleBoxFlat.new()
	style.bg_color = Color("33241a") if in_cart > 0 else Color("2a1c12")
	style.border_color = GameData.category_color(item["cat"]).darkened(0.25)
	style.border_width_left = 4
	style.set_corner_radius_all(4)
	style.content_margin_left = 6
	style.content_margin_right = 6
	style.content_margin_top = 3
	style.content_margin_bottom = 3
	card.add_theme_stylebox_override("panel", style)
	card.mouse_entered.connect(_on_item_hovered.bind(id, card))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	card.add_child(row)

	var icon := TextureRect.new()
	icon.texture = GameData.icon_texture(id)
	icon.custom_minimum_size = Vector2(36, 36)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(icon)
	var names := VBoxContainer.new()
	names.add_theme_constant_override("separation", 0)
	names.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	names.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(names)
	var name_label := _label(item["name"], 14, GOLD, false)
	name_label.clip_text = true
	names.add_child(name_label)
	names.add_child(_rich_label("%s  [color=#8a7a6a]на складі %d[/color]" % [_m(GameState.item_cost(id)), GameState.storage.count(id)], 13))

	var room := _cart_room(id)
	var minus := Button.new()
	minus.text = "−"
	minus.custom_minimum_size = Vector2(28, 28)
	minus.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	minus.disabled = in_cart <= 0
	minus.pressed.connect(_on_cart_change.bind(id, -1))
	row.add_child(minus)
	var qty := _label("%d" % in_cart, 15, TEXT if in_cart > 0 else MUTED, false)
	qty.custom_minimum_size = Vector2(22, 0)
	qty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	qty.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(qty)
	var plus := Button.new()
	plus.text = "+"
	plus.custom_minimum_size = Vector2(28, 28)
	plus.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	plus.disabled = room <= 0
	plus.pressed.connect(_on_cart_change.bind(id, 1))
	row.add_child(plus)
	if room <= 0:
		var place_id := GameData.storage_of_category(item["cat"])
		var place_full: bool = GameState.storage.free_space(place_id) - GameState.order_places(_cart).get(place_id, 0) <= 0
		plus.tooltip_text = ("У сховищі «%s» більше немає місця" % GameData.storage_name_of(id)) if place_full else "Не вистачає грошей"
	else:
		plus.tooltip_text = "Додати в кошик «%s»" % item["name"]
	return card


func _on_cart_change(id: String, delta: int) -> void:
	if delta > 0 and _cart_room(id) < delta:
		return
	var n: int = _cart.get(id, 0) + delta
	if n <= 0:
		_cart.erase(id)
	else:
		_cart[id] = n
	_refresh_market()


func _on_cart_clear() -> void:
	_cart.clear()
	_refresh_market()


func _on_cart_buy() -> void:
	var order := _cart.duplicate()
	_cart.clear()
	if not GameState.buy_order(order):
		_cart = order
	_refresh_market()


# ---------- Alchemy window ----------

func _build_alchemy_window(parent: Control) -> void:
	var box := _panel(parent, Color(0.15, 0.1, 0.07, 1.0))
	_alchemy_window = box.get_parent()
	_alchemy_window.visible = false
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 16)
	box.add_child(header)
	var title := _label("⚗ Алхімія", 22, GOLD, false)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	var close := Button.new()
	close.text = "Закрити (Esc)"
	close.pressed.connect(_close_alchemy)
	header.add_child(close)
	box.add_child(_label("Інгредієнти беруться з горища, готове зілля ставиться в шафу (склад внизу). Варка дій не витрачає. Бракує інгредієнтів? Сходи в ліс чи на кладовище або купи на ринку.", 15, MUTED))
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(scroll)
	_alchemy_cards = HBoxContainer.new()
	_alchemy_cards.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_alchemy_cards.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_alchemy_cards.add_theme_constant_override("separation", 12)
	scroll.add_child(_alchemy_cards)
	_alchemy_result = _rich_label("", 16, TEXT)
	box.add_child(_alchemy_result)


## Mortar standing in the tavern (left part of the screen). Click opens the alchemy window.
func _build_alchemy_object(parent: Control) -> void:
	_alchemy_object = Button.new()
	_alchemy_object.flat = true
	_alchemy_object.icon = _alchemy_icon()
	_alchemy_object.expand_icon = true
	_alchemy_object.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_alchemy_object.custom_minimum_size = Vector2(112, 112)
	_alchemy_object.focus_mode = Control.FOCUS_NONE
	_alchemy_object.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_alchemy_object.add_theme_color_override("icon_hover_color", Color(1.35, 1.25, 0.95))
	_alchemy_object.add_theme_color_override("icon_pressed_color", Color(1.15, 1.05, 0.8))
	# Outside the morning the mortar just looks a bit darker, still part of the room.
	_alchemy_object.add_theme_color_override("icon_disabled_color", Color(0.75, 0.7, 0.65))
	_alchemy_object.anchor_left = 0.5
	_alchemy_object.anchor_right = 0.5
	_alchemy_object.anchor_top = 1.0
	_alchemy_object.anchor_bottom = 1.0
	_alchemy_object.offset_left = -56
	_alchemy_object.offset_right = 56
	# Aligned to the 4x background pixels so the mortar stands on the counter.
	_alchemy_object.offset_top = -138
	_alchemy_object.offset_bottom = -26
	_alchemy_object.pressed.connect(_open_alchemy)
	parent.add_child(_alchemy_object)
	var caption := _label("Алхімія", 16, GOLD, false)
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caption.add_theme_color_override("font_outline_color", Color.BLACK)
	caption.add_theme_constant_override("outline_size", 6)
	caption.anchor_left = 0.5
	caption.anchor_right = 0.5
	caption.anchor_top = 1.0
	caption.anchor_bottom = 1.0
	caption.offset_left = -60
	caption.offset_right = 60
	caption.offset_top = -30
	caption.offset_bottom = -4
	caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# The caption shows only on hover, so the mortar reads as part of the background.
	caption.visible = false
	_alchemy_object.mouse_entered.connect(func() -> void: caption.visible = true)
	_alchemy_object.mouse_exited.connect(func() -> void: caption.visible = false)
	parent.add_child(caption)


func _alchemy_icon() -> Texture2D:
	# Hand-drawn mortar in the background's pixel style; falls back to the icon sheet.
	if ResourceLoader.exists(ALCHEMY_SPRITE):
		return load(ALCHEMY_SPRITE)
	var icon: Array = GameData.ALCHEMY_ICON
	var tex: Texture2D = load(GameData.ICON_SHEETS[icon[0]])
	var cell := Vector2(tex.get_width() / float(GameData.ICON_SHEET_COLUMNS), tex.get_height() / float(GameData.ICON_SHEET_ROWS))
	var atlas := AtlasTexture.new()
	atlas.atlas = tex
	atlas.region = Rect2((Vector2(icon[1], icon[2]) * cell).round(), cell.floor())
	return atlas


func _open_alchemy() -> void:
	if GameState.phase != GameState.Phase.MARKET:
		return
	_market_window.visible = false
	_close_travel_popup()
	_alchemy_window.visible = true
	_refresh_alchemy()


func _close_alchemy() -> void:
	_alchemy_window.visible = false


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE):
		return
	if _travel_popup.visible:
		_close_travel_popup()
		get_viewport().set_input_as_handled()
	elif _alchemy_window.visible:
		_close_alchemy()
		get_viewport().set_input_as_handled()
	elif _market_window.visible:
		_close_market()
		get_viewport().set_input_as_handled()


func _refresh_alchemy() -> void:
	# Brewing is a morning activity: the window closes by itself when the tavern opens.
	var morning := GameState.phase == GameState.Phase.MARKET
	_alchemy_object.disabled = not morning
	_alchemy_object.tooltip_text = "Відкрити алхімію" if morning else "Варити зілля можна лише зранку, поки таверна зачинена"
	if not morning:
		_alchemy_window.visible = false
	if not _alchemy_window.visible:
		return
	for child in _alchemy_cards.get_children():
		_alchemy_cards.remove_child(child)
		child.queue_free()
	for potion_id in GameData.RECIPES:
		_alchemy_cards.add_child(_make_recipe_card(potion_id))
	var brew: Dictionary = GameState.last_brew
	_alchemy_result.text = ""
	if not brew.is_empty():
		var potion_name: String = GameData.ITEMS[brew["item"]]["name"]
		if brew["ok"]:
			_alchemy_result.text = "[color=#a8d08d]Зварено:[/color] %s %s, воно вже на складі." % [GameData.icon_bbcode(brew["item"], 22), potion_name]
		else:
			_alchemy_result.text = "[color=#e08a7a]«%s» не влізе: у сховищі «%s» немає місця. Продай щось звідти.[/color]" % [potion_name, GameData.storage_name_of(brew["item"])]


func _make_recipe_card(potion_id: String) -> Control:
	var item: Dictionary = GameData.ITEMS[potion_id]
	var recipe: Dictionary = GameData.RECIPES[potion_id]
	var card := PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var style := StyleBoxFlat.new()
	style.bg_color = Color("2a1c12")
	style.border_color = GameData.category_color("potion").darkened(0.3)
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	style.set_content_margin_all(10)
	card.add_theme_stylebox_override("panel", style)
	card.mouse_entered.connect(_on_item_hovered.bind(potion_id, card))
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	card.add_child(col)

	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 8)
	col.add_child(head)
	var icon := TextureRect.new()
	icon.texture = GameData.icon_texture(potion_id)
	icon.custom_minimum_size = Vector2(44, 44)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	head.add_child(icon)
	var names := VBoxContainer.new()
	names.add_theme_constant_override("separation", 0)
	names.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(names)
	names.add_child(_label(item["name"], 17, GOLD, false))
	var sub := "Продаж: %s" % _m(GameState.item_price(potion_id))
	if item.has("hero_stats"):
		sub += "  ·  герою %s" % GameData.stats_text(item["hero_stats"], true, true)
	names.add_child(_rich_label("[color=#b8a48c]%s[/color]" % sub, 13))

	for ing in recipe["ingredients"]:
		var need: int = recipe["ingredients"][ing]
		var have := GameState.storage.count(ing)
		var color := "e08a7a" if have < need else "a8d08d"
		col.add_child(_rich_label("%s %s ×%d  [color=#%s](є %d)[/color]" % [GameData.icon_bbcode(ing, 22), GameData.ITEMS[ing]["name"], need, color, have], 14))

	var filler := Control.new()
	filler.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(filler)
	var amount: int = recipe.get("amount", 1)
	var caption := "Зварити" if amount == 1 else "Зварити ×%d" % amount
	if not GameState.is_unlocked(recipe):
		var need := GameData.rep_needed(recipe)
		caption = "Потрібна репутація %d\n(«%s»)" % [need, GameData.rep_rank_name(need)]
		card.modulate = Color(1, 1, 1, 0.6)
	var b := _button(caption, GameState.brew.bind(potion_id), not GameState.can_brew(potion_id), col)
	b.tooltip_text = _recipe_tooltip(potion_id)
	return card


## Ingredient icons with "have/need" counts; missing ones in red.
func _recipe_bbcode(potion_id: String) -> String:
	var parts: PackedStringArray = []
	var ings: Dictionary = GameData.RECIPES[potion_id]["ingredients"]
	for ing in ings:
		var have := GameState.storage.count(ing)
		var color := "e08a7a" if have < ings[ing] else "a8d08d"
		parts.append("%s[color=#%s]%d/%d[/color]" % [GameData.icon_bbcode(ing, 20), color, have, ings[ing]])
	return "  ".join(parts)


func _recipe_tooltip(potion_id: String) -> String:
	var recipe: Dictionary = GameData.RECIPES[potion_id]
	var lines: PackedStringArray = ["Рецепт «%s»:" % GameData.ITEMS[potion_id]["name"]]
	for ing in recipe["ingredients"]:
		var where := GameData.item_locations(ing)
		if GameData.is_buyable(ing):
			where.append("ринок")
		lines.append("  %s ×%d  (є %d; %s)" % [GameData.ITEMS[ing]["name"], recipe["ingredients"][ing], GameState.storage.count(ing), ", ".join(where).to_lower()])
	lines.append("Результат: %d шт." % recipe.get("amount", 1))
	return "\n".join(lines)


func _location_tooltip(loc: Dictionary) -> String:
	var lines: PackedStringArray = []
	if loc.has("count"):
		lines.append("Ресурсів за похід: %d–%d. Можна знайти:" % [loc["count"][0], loc["count"][1]])
		var top := 0.0
		for entry in loc["loot"]:
			top = maxf(top, entry["weight"])
		for entry in loc["loot"]:
			lines.append("%s%s" % [GameData.ITEMS[entry["item"]]["name"], " (рідко)" if entry["weight"] * 3 <= top else ""])
	else:
		for entry in loc["loot"]:
			var amount := "%d" % entry["min"] if entry["min"] == entry["max"] else "%d–%d" % [entry["min"], entry["max"]]
			var line := "%s: %s шт." % [GameData.ITEMS[entry["item"]]["name"], amount]
			if entry.has("chance"):
				line += " (шанс %d%%)" % roundi(entry["chance"] * 100)
			lines.append(line)
	var events: PackedStringArray = []
	for e in loc.get("events", []):
		var conds: PackedStringArray = []
		if e["chance"] > 0.0:
			conds.append("%d%%" % roundi(e["chance"] * 100))
		for contract_id in e.get("always_if_contract", []):
			conds.append("завжди, поки є контракт «%s»" % GameData.CONTRACTS[contract_id]["title"])
		events.append("%s (%s)" % [GameData.LOCATION_EVENTS[e["id"]]["name"], "; ".join(conds)])
	if not events.is_empty():
		lines.append("Можливі події: " + ", ".join(events))
	return "\n".join(lines)


func _counts_bbcode(counts: Dictionary) -> String:
	var parts: PackedStringArray = []
	for id in counts:
		parts.append("%s ×%d" % [GameData.icon_bbcode(id, 20), counts[id]])
	return "  ".join(parts)


func _show_customer() -> void:
	var c: Dictionary = GameState.current_customer
	var tag: String = c["tag"]
	var cat: Dictionary = GameData.CATEGORIES[tag]
	_content.add_child(_rich_label("«Шукаю щось із категорії %s.»" % _tag_bbcode(tag), 20, GOLD))
	var choices := GameState.storage.ids_in_category(tag)
	if choices.is_empty():
		_content.add_child(_label("На складі немає нічого з категорії «%s»." % cat["name"], 15, Color("e08a7a")))
		_button("Розвести руками", GameState.refuse)
		return
	if not _offer_item in choices:
		_offer_item = choices[0]
	_content.add_child(_label("Що запропонувати:", 15, MUTED))
	for id in choices:
		var mark := "▶ " if id == _offer_item else ""
		var text := "%s%s %s  ×%d" % [mark, GameData.icon_bbcode(id, 24), GameData.ITEMS[id]["name"], GameState.storage.count(id)]
		var b := _button(text, _on_offer_selected.bind(id))
		b.mouse_entered.connect(_on_item_hovered.bind(id, b))
	_content.add_child(HSeparator.new())
	_content.add_child(_rich_label("Ціна «%s» сьогодні: %s" % [GameData.ITEMS[_offer_item]["name"], _m(GameState.item_price(_offer_item))], 15, MUTED))
	for i in GameData.PRICE_OPTIONS.size():
		var opt: Dictionary = GameData.PRICE_OPTIONS[i]
		var text := "%s: %s  (згода ~%d%%)" % [opt["label"], _m(GameState.sale_price(_offer_item, i)), roundi(GameState.sale_chance(i) * 100)]
		_button(text, GameState.serve.bind(_offer_item, i))
	_button("Відмовити", GameState.refuse)


func _show_quest_offer() -> void:
	var hero := GameState.current_hero()
	var asks: bool = GameState.current_customer.get("asks_contract", false)
	if asks:
		_content.add_child(_label("«Маєш для мене якусь роботу?»", 20, GOLD))
	else:
		_content.add_child(_label("Запропонувати герою контракт?", 20, GOLD))
		_content.add_child(_label("Він сам роботи не питав, тож на надто ризиковані контракти не погодиться.", 14, MUTED))
	_content.add_child(_rich_label("%s, %s: сума характеристик [b]%d[/b]" % [hero["name"], GameData.HERO_CLASSES[hero["class"]]["name"].to_lower(), GameData.stats_sum(hero["stats"])], 15))
	_content.add_child(_label("Якщо контракт виконано: твоя частка нагороди, репутація +%d/+%d/+%d (за складністю) і процвітання +%d. Якщо ні, герой повернеться пораненим (репутація %d) або загине (репутація %d)." % [GameData.CONTRACT_TIERS["easy"]["rep"], GameData.CONTRACT_TIERS["medium"]["rep"], GameData.CONTRACT_TIERS["hard"]["rep"], GameData.PROSPERITY_ON_QUEST_SUCCESS, GameData.REP_HERO_INJURED, GameData.REP_HERO_DIED], 14, MUTED))
	var items := GameState.hero_item_choices()
	if not _hero_item in items:
		_hero_item = ""
	if not items.is_empty():
		_content.add_child(_label("Дати з собою:", 15, MUTED))
		_button(("▶ " if _hero_item == "" else "") + "Нічого", _on_hero_item_selected.bind(""))
		for id in items:
			var item: Dictionary = GameData.ITEMS[id]
			var mark := "▶ " if id == _hero_item else ""
			var note := "повернеться" if item["cat"] in GameData.RETURNING_CATEGORIES else "витратиться"
			var text := "%s%s %s  [color=#b8a48c]%s, %s[/color]" % [mark, GameData.icon_bbcode(id, 24), item["name"], GameData.stats_text(item.get("hero_stats", {}), true, true), note]
			var b := _button(text, _on_hero_item_selected.bind(id))
			b.mouse_entered.connect(_on_item_hovered.bind(id, b))
		_content.add_child(HSeparator.new())
	for i in GameState.quest_board.size():
		var q: Dictionary = GameState.quest_board[i]
		var tier: Dictionary = GameData.CONTRACT_TIERS[q["tier"]]
		var chance := GameState.quest_chance(q, _hero_item)
		var will := GameState.hero_will_take(q, _hero_item)
		var line2 := "%s · %d дн. · %s · %s" % [tier["name"], q["days"], _m(q["reward"]), GameData.risk_bbcode(chance)]
		if not will:
			line2 += "  [color=#e08a7a](не погодиться)[/color]"
		var b := _button("%s\n[color=#b8a48c]%s[/color]" % [q["title"], line2], _on_assign.bind(i), not will)
		var loot_names: PackedStringArray = []
		for entry in q["loot"]:
			loot_names.append(GameData.ITEMS[entry["item"]]["name"])
		b.tooltip_text = "%s\nСкладність %d, сила героя %d.\nМожливі трофеї: %s" % [q["desc"], q["diff"], GameState.hero_power(hero, _hero_item), ", ".join(loot_names) if not loot_names.is_empty() else "немає"]
	_button("Нічого не пропонувати", GameState.skip_quest)


func _show_brawl() -> void:
	var b: Dictionary = GameData.BRAWL
	_content.add_child(_label(b["name"] + "!", 22, Color("e0904a")))
	_content.add_child(_label("Двоє гостей не поділили лавку. Летять кухлі, тріщать стільці, решта відвідувачів підбадьорює.", 16))
	_content.add_child(HSeparator.new())
	var lost: int = b["lost_customers"]
	_button("Розборонити  [color=#b8a48c](наступний гість піде без покупки)[/color]" if lost == 1 else "Розборонити  [color=#b8a48c](%d наступних гостей підуть без покупок)[/color]" % lost, GameState.resolve_brawl.bind(true))
	_button("Не втручатися  [color=#b8a48c](репутація %d)[/color]" % b["rep"], GameState.resolve_brawl.bind(false))


func _show_evening() -> void:
	var s: Dictionary = GameState.day_stats
	_content.add_child(_label("Підсумки %d-го дня" % GameState.day, 20, GOLD))
	_content.add_child(_rich_label("Продажів: %d, виручка: %s" % [s["sales"], _m(s["income"])]))
	_content.add_child(_rich_label("Від героїв: %s" % _m(s["quest_income"])))
	_content.add_child(_label("Походів: %d, зібрано ресурсів: %d, зварено зілль: %d" % [s["trips"], s["gathered"], s["brewed"]]))
	_content.add_child(_rich_label("Витрати на ринку: %s, утримання: %s" % [_m(s["spent"]), _m(GameData.DAILY_UPKEEP)]))
	if s.get("tax", 0) > 0:
		_content.add_child(_rich_label("Податок: %s" % _m(s["tax"])))
	_content.add_child(_label("Невдоволених клієнтів: %d" % s["refused"]))
	_content.add_child(_rich_label("До мети: ще %s і %d дн." % [_m(maxi(0, GameData.GOAL_MONEY - GameState.wallet.total)), GameData.LAST_DAY - GameState.day]))
	_button("Наступний день", GameState.next_day, false, _footer)


func _show_game_over() -> void:
	_content.add_child(_label("Перемога!" if GameState.won else "Кінець гри", 26, GOLD))
	_content.add_child(_rich_label("Гаманець: %s, репутація: %d («%s»), днів: %d" % [GameState.wallet.format(true), GameState.reputation, GameState.rep_rank()["name"], GameState.day]))
	_button("Нова гра", _on_new_game, false, _footer)


func _m(amount: int) -> String:
	return Wallet.format_amount(amount, true)


# ---------- Callbacks ----------

func _on_offer_selected(id: String) -> void:
	_offer_item = id
	_refresh()


func _on_hero_item_selected(id: String) -> void:
	_hero_item = id
	_refresh()


func _on_item_hovered(id: String, source: Control) -> void:
	if id == "" or source == null:
		return
	_tip_source = source
	_show_item_info(id)
	_tip.visible = true


func _on_assign(index: int) -> void:
	var item := _hero_item
	_hero_item = ""
	GameState.assign_quest(index, item)


func _on_new_game() -> void:
	_log.clear()
	_last_event.text = ""
	GameState.new_game()


func _on_heroes_pressed() -> void:
	_heroes_text.text = _heroes_bbcode()
	_heroes_popup.popup_centered()


func _on_rep_pressed() -> void:
	_rep_text.text = _rep_bbcode()
	_rep_popup.popup_centered()


func _on_log_pressed() -> void:
	_log_popup.popup_centered()


func _on_logged(text: String) -> void:
	_log.append_text(text + "\n")
	var line := text.strip_edges()
	if line != "":
		_last_event.text = line
