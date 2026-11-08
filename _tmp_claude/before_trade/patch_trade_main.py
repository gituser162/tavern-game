#!/usr/bin/env python3
"""Trade rework, main.gd part: sale tray on the counter, drag shelf pieces onto it, -10% / sell / +10%."""
import sys, pathlib

p = pathlib.Path(sys.argv[1]) / "scripts" / "main.gd"
text = p.read_text(encoding="utf-8")


def patch(old, new, count=1):
    global text
    n = text.count(old)
    if n != count:
        sys.exit(f"expected {count} match(es), got {n}:\n{old[:300]}")
    text = text.replace(old, new)


patch('''const BUBBLE_RECT := Rect2(187, 12, 124, 73)
''', '''const BUBBLE_RECT := Rect2(187, 12, 124, 73)
## Sale tray: a small window on the counter in front of the visitor (bg px).
const SALE_RECT := Rect2(95, 63, 91, 38)
''')

patch('''var _info_uid := 0
''', '''var _info_uid := 0

# Sale tray (shelf pieces dragged onto it are offered to the visitor).
var _sale_tray: PanelContainer
var _sale_style: StyleBoxFlat
var _sale_box: VBoxContainer
var _sale_error := ""
var _sale_customer := -1
''')

patch('''	_build_bubble()
	_build_info_panel()
''', '''	_build_bubble()
	_build_sale_tray()
	_build_info_panel()
''')

patch('''	_place_storage_popup()


# ---------- Storages''', '''	_place_storage_popup()
	if _sale_tray != null:
		var s := _bg_to_screen(SALE_RECT)
		_sale_tray.global_position = s.position
		_sale_tray.size = s.size


# ---------- Sale tray ----------
## The visitor wants one or two categories and has a purse. The keeper drags pieces from the shelves onto
## this tray (they stay on the shelf, hidden, until sold; click one on the tray to put it back), then sells,
## gives -10% (reputation) or tries +10% (the visitor may say no or even leave).

func _build_sale_tray() -> void:
	_sale_tray = PanelContainer.new()
	_sale_style = StyleBoxFlat.new()
	_sale_style.bg_color = Color(0.16, 0.1, 0.06, 0.95)
	_sale_style.border_color = BUBBLE_EDGE
	_sale_style.set_border_width_all(2)
	_sale_style.set_corner_radius_all(6)
	_sale_style.set_content_margin_all(6)
	_sale_style.shadow_color = Color(0, 0, 0, 0.4)
	_sale_style.shadow_size = 4
	_sale_tray.add_theme_stylebox_override("panel", _sale_style)
	_sale_tray.visible = false
	add_child(_sale_tray)
	_sale_box = VBoxContainer.new()
	_sale_box.add_theme_constant_override("separation", 4)
	_sale_tray.add_child(_sale_box)


## Border of the tray while a piece is dragged over it: 1 = it can go there (green), -1 = not (red), 0 = normal.
func _sale_set_hover(state: int) -> void:
	if _sale_style == null:
		return
	_sale_style.border_color = Color(0.45, 0.9, 0.4) if state > 0 else (Color(0.95, 0.35, 0.3) if state < 0 else BUBBLE_EDGE)
	_sale_style.set_border_width_all(3 if state != 0 else 2)


func _over_sale_tray() -> bool:
	return _sale_tray != null and _sale_tray.visible and _sale_tray.get_global_rect().grow(6).has_point(get_global_mouse_position())


## A dragged piece was let go over the tray.
func _sale_drop(t: TextureRect, uid: int) -> void:
	if _drag["r"] != _drag["r0"]:
		_turn_piece_node(t, _drag["id"], _drag["r0"])
	var err := GameState.deal_put(uid)
	if err == "":
		_sale_error = ""
		t.position = _drag_start_pos
		t.visible = false
		Audio.play("shelf")
	else:
		_sale_error = err
		Audio.play("error")
		var tw := create_tween()
		tw.tween_property(t, "position", _drag_start_pos, 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		_refresh_sale_tray()


## Pieces lying on the tray are hidden on their shelf.
func _sync_deal_pieces() -> void:
	for place_id in _shelf_nodes:
		var nodes: Dictionary = _shelf_nodes[place_id]
		for uid in nodes:
			var t: TextureRect = nodes[uid]
			if is_instance_valid(t) and not (_drag.get("node") == t):
				t.visible = not GameState.deal_has(uid)


func _refresh_sale_tray() -> void:
	if _sale_tray == null:
		return
	# Pieces that left the storage some other way (brewing...) drop off the tray.
	for e in GameState.deal.duplicate():
		if GameState.storage.id_of_uid(e["uid"]) == "":
			GameState.deal.erase(e)
	if _sale_customer != GameState.customer_index:
		_sale_customer = GameState.customer_index
		_sale_error = ""
	_sync_deal_pieces()
	for child in _sale_box.get_children():
		_sale_box.remove_child(child)
		child.queue_free()
	if not GameState.trading():
		return
	var deal: Array = GameState.deal
	# Row 1: slots + total.
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	_sale_box.add_child(row)
	for i in GameData.DEAL_SLOTS:
		var b := Button.new()
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(40, 40)
		var slot := StyleBoxFlat.new()
		slot.bg_color = Color(0, 0, 0, 0.35)
		slot.border_color = Color("6b4a2f")
		slot.set_border_width_all(1)
		slot.set_corner_radius_all(4)
		var slot_hover := slot.duplicate()
		slot_hover.border_color = GOLD
		for st in ["normal", "disabled", "focus"]:
			b.add_theme_stylebox_override(st, slot)
		for st in ["hover", "pressed"]:
			b.add_theme_stylebox_override(st, slot_hover)
		if i < deal.size():
			var e: Dictionary = deal[i]
			b.icon = GameData.icon_texture(e["id"])
			b.expand_icon = true
			b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
			b.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
			b.pressed.connect(func() -> void:
				Audio.play("shelf")
				GameState.deal_remove(e["uid"]))
			b.mouse_entered.connect(_on_item_hovered.bind(e["id"], b, e["uid"]))
		else:
			b.disabled = true
			b.tooltip_text = "Перетягни сюди товар з полиці"
		row.add_child(b)
	var sums := VBoxContainer.new()
	sums.add_theme_constant_override("separation", 0)
	sums.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(sums)
	var total := GameState.deal_total()
	var purse := GameState.customer_purse()
	var step_txt := ""
	if GameState.deal_step < 0:
		step_txt = " [color=#7fc97f]−10%[/color]"
	elif GameState.deal_step > 0:
		step_txt = " [color=#e0b060]+10%[/color]"
	sums.add_child(_rich_label("Разом %s%s" % [_m(total), step_txt], 14, TEXT))
	var purse_col := "#e08a7a" if total > purse else "#b8a48c"
	sums.add_child(_rich_label("[color=%s]Гаманець %s[/color]" % [purse_col, _m(purse)], 13, MUTED))
	# Row 2: -10% / sell / +10%.
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 4)
	_sale_box.add_child(buttons)
	var raised := GameState.deal_step > 0
	var disc_on := GameState.deal_step < 0
	var disc := _button("[color=#7fc97f]−10% ✓[/color]" if disc_on else "−10%", GameState.deal_toggle_discount, deal.is_empty() or raised, buttons, 13)
	disc.tooltip_text = ("Прибрати знижку." if disc_on else
		"Знижка 10%%: відвідувач заплатить %s, таверна отримає +%d репутації." % [str(GameState.deal_total(-1)), GameData.DEAL_REP_PER_10_OFF])
	var sell_problem := GameState.sell_problem()
	var sell := _button("Продати", GameState.sell_deal, sell_problem != "", buttons, 14)
	sell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sell.tooltip_text = sell_problem if sell_problem != "" else "Продати все з прилавка за %d." % total
	var raise_problem := GameState.raise_problem()
	var chance := roundi(GameState.raise_chance() * 100)
	var raise := _button("+10%% [color=#b8a48c]~%d%%[/color]" % chance, GameState.deal_try_raise, raise_problem != "", buttons, 13)
	raise.tooltip_text = raise_problem if raise_problem != "" else \\
		"Спробувати продати за %d замість %d. Шанс згоди ~%d%%. Якщо ні, ціна лишиться звичайною, але іноді відвідувач ображається й іде (репутація %d)." % [
			GameState.deal_total(1), total, chance, GameData.REP_UNHAPPY_CUSTOMER]
	for b in [disc, sell, raise]:
		b.custom_minimum_size.y = 28
	disc.custom_minimum_size.x = 58
	raise.custom_minimum_size.x = 80
	# Row 3: error / hint / what the keeper earns.
	var note := ""
	if _sale_error != "":
		note = "[color=#e08a7a]%s[/color]" % _sale_error
	elif deal.is_empty():
		note = "[color=#8a7a6a]Перетягни сюди товар з полиць[/color]"
	elif total > purse:
		note = "[color=#e08a7a]Не вистачає %d: забери щось із прилавка[/color]" % (total - purse)
	else:
		var cost := GameState.deal_cost()
		var rep := GameState.deal_discount_rep()
		note = "[color=#8a7a6a]Закупка %d · зиск %+d[/color]" % [cost, total - cost]
		if rep > 0:
			note += "  [color=#7fc97f]репутація +%d[/color]" % rep
	_sale_box.add_child(_rich_label(note, 12, MUTED))


# ---------- Storages''')

patch('''	_refresh_client()
	_refresh_storage()
''', '''	_refresh_client()
	_refresh_storage()
	_refresh_sale_tray()
''')

patch('''	_process_shelves()
''', '''	_process_shelves()
	if _sale_tray != null:
		_sale_tray.visible = GameState.trading() and not _shelves_covered()
''')

patch('''		_client_title.text = "%s, %s   %s" % [c["name"], String(c["title"]).to_lower(), _tag_bbcode(c["tag"])]
''', '''		var tags: PackedStringArray = []
		for cat in GameState.customer_wants_list():
			tags.append(_tag_bbcode(cat))
		_client_title.text = "%s, %s   %s" % [c["name"], String(c["title"]).to_lower(), " ".join(tags)]
''')

# --- bubble text for a visitor ---
start = text.index("func _show_customer() -> void:")
end = text.index("## Row of item icons to choose from")
patch(text[start:end], '''func _show_customer() -> void:
	var wants := GameState.customer_wants_list()
	var tags: PackedStringArray = []
	var names: PackedStringArray = []
	var in_stock := false
	for cat in wants:
		tags.append(_tag_bbcode(cat))
		names.append("«%s»" % GameData.CATEGORIES[cat]["name"])
		if not GameState.storage.ids_in_category(cat).is_empty():
			in_stock = true
	_content.add_child(_rich_label("«Шукаю %s. Маю при собі %s.»" % [" або ".join(tags), _m(GameState.customer_purse())], 17, GOLD))
	if not in_stock and GameState.deal.is_empty():
		_content.add_child(_label("У сховищах немає нічого з %s." % " чи ".join(names), 14, Color("e08a7a")))
		_button("Розвести руками", GameState.refuse)
		return
	_content.add_child(_label("Перетягни потрібні товари з полиць на прилавок перед відвідувачем (до %d за раз). Там можна продати, дати знижку −10%% (+%d репутації) або спробувати підняти ціну на +10%%." % [GameData.DEAL_SLOTS, GameData.DEAL_REP_PER_10_OFF], 13, MUTED))
	_button("Відмовити", GameState.refuse)


''')

# --- reputation window text ---
patch('''і продажу «Дешево» (+%d). Падає, коли відвідувач іде невдоволений (%d), за «Здирство» (%d), коли''',
      '''і продажу зі знижкою (+%d за кожні 10%%). Падає, коли відвідувач іде невдоволений (%d), коли''')
patch('''		GameData.PRICE_OPTIONS[0]["rep"], GameData.REP_UNHAPPY_CUSTOMER, GameData.PRICE_OPTIONS[3]["rep"], GameData.REP_HERO_INJURED, GameData.REP_HERO_DIED])''',
      '''		GameData.DEAL_REP_PER_10_OFF, GameData.REP_UNHAPPY_CUSTOMER, GameData.REP_HERO_INJURED, GameData.REP_HERO_DIED])''')
patch('''до шансу, що відвідувач погодиться на ціну''', '''до шансу, що відвідувач погодиться на +10%''')

# --- dragging onto the tray ---
patch('''func _update_drag_target() -> void:
	var place_id: String = _drag["place"]
''', '''func _update_drag_target() -> void:
	if _over_sale_tray():
		var ok := GameState.customer_accepts(_drag["id"]) and GameState.deal.size() < GameData.DEAL_SLOTS
		_sale_set_hover(1 if ok else -1)
		_drag["target"] = {"tray": true}
		_shelf_overlay.grids = []
		_shelf_overlay.target = Rect2()
		_shelf_overlay.queue_redraw()
		return
	_sale_set_hover(0)
	var place_id: String = _drag["place"]
''')
patch('''	_shelf_overlay.target = Rect2()
	_shelf_overlay.queue_redraw()


func _cancel_drag''', '''	_shelf_overlay.target = Rect2()
	_shelf_overlay.queue_redraw()
	_sale_set_hover(0)


func _cancel_drag''')
patch('''		var turned: bool = _drag["r"]
		if not target.is_empty() and target["ok"]''', '''		var turned: bool = _drag["r"]
		if target.get("tray", false):
			_sale_drop(t, uid)
			_drag = {}
			return
		if not target.is_empty() and target["ok"]''')
patch('''					_shelf_leave(t, k)
				else:
					t.queue_free()
''', '''					_shelf_leave(t, k)
				else:
					t.queue_free()
	_sync_deal_pieces()
''')

p.write_text(text, encoding="utf-8", newline="")
print("patched main.gd")
