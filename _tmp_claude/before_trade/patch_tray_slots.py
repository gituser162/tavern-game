import sys, pathlib
root = pathlib.Path(sys.argv[1]) / "scripts"
def patch(name, pairs):
    p = root / name
    t = p.read_text(encoding="utf-8")
    for old, new in pairs:
        assert t.count(old) == 1, old
        t = t.replace(old, new)
    p.write_text(t, encoding="utf-8", newline="")
patch("game_data.gd", [("const DEAL_SLOTS := 4", "const DEAL_SLOTS := 8")])
patch("main.gd", [
    ('	# Row 1: slots + total.\n	var row := HBoxContainer.new()\n	row.add_theme_constant_override("separation", 6)',
     '	# Row 1: slots. Row 2: total and purse.\n	var row := HBoxContainer.new()\n	row.add_theme_constant_override("separation", 5)'),
    ('b.custom_minimum_size = Vector2(56, 56)', 'b.custom_minimum_size = Vector2(48, 48)'),
    ('	var sums := VBoxContainer.new()\n	sums.add_theme_constant_override("separation", 0)\n	sums.size_flags_horizontal = Control.SIZE_EXPAND_FILL\n	row.add_child(sums)',
     '	var sums := HBoxContainer.new()\n	sums.add_theme_constant_override("separation", 16)\n	_sale_box.add_child(sums)'),
    ('"Разом %s%s" % [_m(total), step_txt], 18, TEXT))', '"Разом %s%s" % [_m(total), step_txt], 18, TEXT))\n	sums.get_child(-1).size_flags_horizontal = Control.SIZE_EXPAND_FILL'),
    ('Гаманець %s[/color]" % [purse_col, _m(purse)], 16, MUTED))', 'Гаманець %s[/color]" % [purse_col, _m(purse)], 16, MUTED))\n	sums.get_child(-1).size_flags_horizontal = Control.SIZE_EXPAND_FILL'),
])
print("ok")
