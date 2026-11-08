import sys, pathlib
p = pathlib.Path(sys.argv[1]) / "scripts" / "main.gd"
t = p.read_text(encoding="utf-8")
for old, new in [
    ('const SALE_RECT := Rect2(95, 63, 91, 38)', 'const SALE_RECT := Rect2(73, 58, 113, 43)'),
    ('_sale_style.set_content_margin_all(6)', '_sale_style.set_content_margin_all(10)'),
    ('b.custom_minimum_size = Vector2(40, 40)', 'b.custom_minimum_size = Vector2(56, 56)'),
    ('"Разом %s%s" % [_m(total), step_txt], 14, TEXT)', '"Разом %s%s" % [_m(total), step_txt], 18, TEXT)'),
    ('Гаманець %s[/color]" % [purse_col, _m(purse)], 13, MUTED)', 'Гаманець %s[/color]" % [purse_col, _m(purse)], 16, MUTED)'),
    ('deal.is_empty() or raised, buttons, 13)', 'deal.is_empty() or raised, buttons, 16)'),
    ('GameState.sell_deal, sell_problem != "", buttons, 14)', 'GameState.sell_deal, sell_problem != "", buttons, 18)'),
    ('GameState.deal_try_raise, raise_problem != "", buttons, 13)', 'GameState.deal_try_raise, raise_problem != "", buttons, 16)'),
    ('b.custom_minimum_size.y = 28', 'b.custom_minimum_size.y = 38'),
    ('disc.custom_minimum_size.x = 58', 'disc.custom_minimum_size.x = 80'),
    ('raise.custom_minimum_size.x = 80', 'raise.custom_minimum_size.x = 110'),
    ('_rich_label(note, 12, MUTED)', '_rich_label(note, 15, MUTED)'),
    ('row.add_theme_constant_override("separation", 4)\n\t_sale_box.add_child(row)', 'row.add_theme_constant_override("separation", 6)\n\t_sale_box.add_child(row)'),
    ('_sale_box.add_theme_constant_override("separation", 4)', '_sale_box.add_theme_constant_override("separation", 8)'),
]:
    assert t.count(old) == 1, old
    t = t.replace(old, new)
p.write_text(t, encoding="utf-8", newline="")
print("ok")
