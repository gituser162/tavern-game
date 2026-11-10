extends RefCounted
## Shared look of the menus: wooden plank buttons (pixel art from tools/menu/gen_menu.py, saved 4x so they match
## the 4x-scaled background) and the dark wooden window used by the game's other windows.

const PLANK := "res://assets/ui/plank_%s.png"
const GOLD := Color("f2c14e")
const TEXT := Color("eadbc8")
const MUTED := Color("8a7a6a")


static func plank_style(kind: String) -> StyleBox:
	var path := PLANK % kind
	if not ResourceLoader.exists(path):
		var flat := StyleBoxFlat.new()
		flat.bg_color = Color("6a4426") if kind != "disabled" else Color("3a322c")
		flat.set_border_width_all(2)
		flat.border_color = Color("1a0f0a")
		return flat
	var st := StyleBoxTexture.new()
	st.texture = load(path)
	st.set_texture_margin_all(16)
	st.content_margin_left = 24
	st.content_margin_right = 24
	st.content_margin_top = 6
	st.content_margin_bottom = 10
	return st


## A big wooden menu button.
static func plank_button(text: String, width: float = 300) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(width, 52)
	b.focus_mode = Control.FOCUS_NONE
	b.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	b.add_theme_font_size_override("font_size", 20)
	b.add_theme_color_override("font_color", TEXT)
	b.add_theme_color_override("font_hover_color", Color("fff2c8"))
	b.add_theme_color_override("font_pressed_color", GOLD)
	b.add_theme_color_override("font_disabled_color", Color("8a7a6a"))
	b.add_theme_color_override("font_outline_color", Color("1a0f0a"))
	b.add_theme_constant_override("outline_size", 6)
	b.add_theme_stylebox_override("normal", plank_style("normal"))
	b.add_theme_stylebox_override("hover", plank_style("hover"))
	b.add_theme_stylebox_override("pressed", plank_style("pressed"))
	b.add_theme_stylebox_override("hover_pressed", plank_style("pressed"))
	b.add_theme_stylebox_override("disabled", plank_style("disabled"))
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	return b


## Dark wooden window (same as the ledger and the storage windows).
static func window_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.085, 0.05, 0.03, 0.96)
	style.border_color = Color("6b4a2f")
	style.set_border_width_all(3)
	style.set_corner_radius_all(6)
	style.set_content_margin_all(22)
	style.shadow_color = Color(0, 0, 0, 0.5)
	style.shadow_size = 10
	return style


static func title(text: String, size: int = 26) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", GOLD)
	l.add_theme_color_override("font_outline_color", Color("1a0f0a"))
	l.add_theme_constant_override("outline_size", 8)
	return l


static func text_label(text: String, size: int = 16, color: Color = TEXT) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l


## A window in the middle of the screen: dark backdrop over everything + the wooden panel.
## Returns {"root": full-screen Control, "box": VBoxContainer inside the panel}.
static func modal(parent: Node, min_width: float = 420) -> Dictionary:
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	root.visible = false
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(center)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", window_style())
	panel.custom_minimum_size = Vector2(min_width, 0)
	center.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	panel.add_child(box)
	parent.add_child(root)
	return {"root": root, "box": box}
