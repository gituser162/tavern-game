"""Hooks the Audio autoload into game_state.gd, main.gd and project.godot. Run from the project root."""
import sys, re

def patch(path, pairs):
    s = open(path, encoding="utf-8").read()
    for old, new in pairs:
        if s.count(old) != 1:
            sys.exit(f"{path}: anchor found {s.count(old)} times:\n{old}")
        s = s.replace(old, new)
    open(path, "w", encoding="utf-8", newline="\n").write(s)

T = "\t"
patch("scripts/game_state.gd", [
    ('\t\ttown_event = "tax"\n', '\t\ttown_event = "tax"\n\t\tAudio.play("tax", 0.6)\n'),
    ('\t\ttown_event = "fair"\n', '\t\ttown_event = "fair"\n\t\tAudio.play("fair", 0.6)\n'),
    ('\t_log("Ти йдеш на міський ринок.")\n', '\tAudio.play("door")\n\t_log("Ти йдеш на міський ринок.")\n'),
    ('\t_log("Ринок: куплено', '\tAudio.play("buy")\n\t_log("Ринок: куплено'),
    ('\t\t\t_log("[color=salmon]Зварити', '\t\t\tAudio.play("error")\n\t\t\t_log("[color=salmon]Зварити'),
    ('\t_log("Ти вариш', '\tAudio.play("brew")\n\t_log("Ти вариш'),
    ('\tday_stats["trips"] += 1\n', '\tday_stats["trips"] += 1\n\tAudio.play("door")\n'),
    ('\t\tclosed_locations.append(location_id)\n', '\t\tclosed_locations.append(location_id)\n\t\tAudio.play("expelled", 0.6)\n'),
    ('\tif not event.is_empty():\n\t\t_log("Похід:',
     '\tif not event.is_empty():\n\t\tAudio.play("magic" if effect in ["loot_mult", "timed_rare"] else "event", 0.6)\n\t\t_log("Похід:'),
    ('\tday_stats["gathered"] += 1\n', '\tAudio.play("gather")\n\tday_stats["gathered"] += 1\n'),
    ('\ttrip["grave"] = "searched"\n', '\ttrip["grave"] = "searched"\n\tAudio.play("dig")\n\tAudio.play("grave_loot", 0.75)\n'),
    ('\tvar expelled: bool = GameData.LOCATION_EVENTS.get(trip["event"], {}).get("effect", "") == "expel"\n\ttrip = {}\n',
     '\tvar expelled: bool = GameData.LOCATION_EVENTS.get(trip["event"], {}).get("effect", "") == "expel"\n\ttrip = {}\n\tAudio.play("door")\n'),
    ('\t\tbrawl_active = true\n\t\t_log(', '\t\tbrawl_active = true\n\t\tAudio.play("brawl")\n\t\t_log('),
    ('\tcurrent_customer = customers_today[customer_index]\n', '\tcurrent_customer = customers_today[customer_index]\n\tAudio.play("visitor", 0.15)\n'),
    ('\t\t_log("%s купує', '\t\tAudio.play("coin")\n\t\t_log("%s купує'),
    ('\t\t_log("%s обурено', '\t\tAudio.play("angry")\n\t\t_log("%s обурено'),
    ('\tvar tag_name: String = GameData.CATEGORIES[current_customer["tag"]]["name"]\n',
     '\tAudio.play("refuse")\n\tvar tag_name: String = GameData.CATEGORIES[current_customer["tag"]]["name"]\n'),
    ('\tif item_id != "":\n\t\ttext += " З собою:', '\tAudio.play("contract")\n\tif item_id != "":\n\t\ttext += " З собою:'),
    ('\t\t\thero["done"] = hero.get("done", 0) + 1\n', '\t\t\thero["done"] = hero.get("done", 0) + 1\n\t\t\tAudio.play("success", 0.6)\n'),
    ('\t\t\theroes.erase(hero)\n', '\t\t\theroes.erase(hero)\n\t\t\tAudio.play("death", 0.6)\n'),
    ('\t\t\thero["injured_until"] = day + GameData.INJURY_DAYS\n', '\t\t\thero["injured_until"] = day + GameData.INJURY_DAYS\n\t\t\tAudio.play("fail", 0.6)\n'),
    ('\t_announced_rank = rank\n', '\tAudio.play("rank_up" if rank > _announced_rank else "rank_down", 1.3)\n\t_announced_rank = rank\n'),
])

patch("scripts/main.gd", [
    ('func _on_bell() -> void:\n', 'func _on_bell() -> void:\n\tAudio.play("bell")\n'),
    ('\t_book_tabs.current_tab = tab\n\t_refresh_book()\n\t_book_popup.popup_centered()\n',
     '\t_book_tabs.current_tab = tab\n\t_refresh_book()\n\tAudio.play("page")\n\t_book_popup.popup_centered()\n'),
    ('\t_open_storage = place_id\n\t_storage_popups[place_id].visible = true\n',
     '\t_open_storage = place_id\n\tAudio.play("open")\n\t_storage_popups[place_id].visible = true\n'),
    ('\t_close_storage()\n\t_travel_popup.visible = true\n', '\t_close_storage()\n\tAudio.play("open")\n\t_travel_popup.visible = true\n'),
    ('\t_close_storage()\n\t_alchemy_window.visible = true\n', '\t_close_storage()\n\tAudio.play("open")\n\t_alchemy_window.visible = true\n'),
    ('func _close_alchemy() -> void:\n', 'func _close_alchemy() -> void:\n\tif _alchemy_window.visible:\n\t\tAudio.play("close")\n'),
    ('func _close_market() -> void:\n', 'func _close_market() -> void:\n\tif _market_window.visible:\n\t\tAudio.play("close")\n'),
    # volume button at the right end of the top bar
    ('\ttop.add_child(_phase_label)\n',
     '\ttop.add_child(_phase_label)\n\t_build_volume_button(top)\n'),
    ('var _book_popup: PopupPanel\n', 'var _book_popup: PopupPanel\n## Music / sound volume popup and the top-bar button that opens it.\nvar _volume_popup: PopupPanel\nvar _volume_button: Button\n'),
    ('func _build_bubble() -> void:\n',
     '''## "Звук" button at the end of the top bar: a small popup with music and sound volume.
func _build_volume_button(parent: Control) -> void:
	_volume_button = Button.new()
	_volume_button.text = "Звук"
	_volume_button.flat = true
	_volume_button.focus_mode = Control.FOCUS_NONE
	_volume_button.tooltip_text = "Гучність музики і звуків"
	_volume_button.add_theme_font_size_override("font_size", 15)
	_volume_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_volume_button.pressed.connect(_open_volume)
	parent.add_child(_volume_button)
	_volume_popup = PopupPanel.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.085, 0.05, 0.03, 0.97)
	style.border_color = Color("6b4a2f")
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	style.set_content_margin_all(14)
	_volume_popup.add_theme_stylebox_override("panel", style)
	_volume_popup.add_child(Audio.make_volume_panel())
	add_child(_volume_popup)


func _open_volume() -> void:
	_volume_popup.reset_size()
	var r := _volume_button.get_global_rect()
	var size := _volume_popup.size
	_volume_popup.popup(Rect2i(Vector2i(int(r.end.x) - size.x, int(r.end.y) + 4), size))


func _build_bubble() -> void:
'''),
])

patch("project.godot", [
    ('GameState="*res://scripts/game_state.gd"\n', 'GameState="*res://scripts/game_state.gd"\nAudio="*res://scripts/audio.gd"\n'),
])
print("patched")
