extends Control
## Market square: the market background (320x180 pixel art) scaled to cover this control,
## with one clickable stall per category. Lit on hover, caption under it.
## Stall rects are in background pixels and match tools/gen_market.py (STALLS).

signal stall_pressed(cat: String)
## A click on the square itself (not on a stall), used to close the stall window.
signal background_pressed

const BG_SIZE := Vector2(320, 180)
const HOVER_TINT := Color(1.3, 1.22, 0.95)
const STALLS := {
	"food": {"rect": Rect2i(4, 42, 60, 70), "name": "Харчова ятка"},
	"drink": {"rect": Rect2i(67, 42, 60, 70), "name": "Шинкар"},
	"resource": {"rect": Rect2i(130, 42, 60, 70), "name": "Травниця"},
	"gear": {"rect": Rect2i(193, 42, 60, 70), "name": "Зброяр"},
	"magic": {"rect": Rect2i(256, 42, 60, 70), "name": "Лавка чарів"},
}

## The stall whose window is open: it stays lit.
var selected := "":
	set(value):
		selected = value
		_update_tints()

var _art: TextureRect
var _buttons := {}
var _hover := ""
var _caption: Label
var _captions := {}


func setup(texture: Texture2D, category_names: Dictionary) -> void:
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	_art = TextureRect.new()
	_art.texture = texture
	_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_art.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_art.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_art)
	for cat in STALLS:
		var b := TextureButton.new()
		var atlas := AtlasTexture.new()
		atlas.atlas = texture
		atlas.region = Rect2(STALLS[cat]["rect"])
		b.texture_normal = atlas
		b.ignore_texture_size = true
		b.stretch_mode = TextureButton.STRETCH_SCALE
		b.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		b.focus_mode = Control.FOCUS_NONE
		b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		b.pressed.connect(func() -> void: stall_pressed.emit(cat))
		b.mouse_entered.connect(_on_hover.bind(cat, true))
		b.mouse_exited.connect(_on_hover.bind(cat, false))
		b.tooltip_text = ""
		add_child(b)
		_buttons[cat] = b
		_captions[cat] = "%s · %s" % [STALLS[cat]["name"], category_names.get(cat, cat)]
	_caption = Label.new()
	_caption.add_theme_font_size_override("font_size", 16)
	_caption.add_theme_color_override("font_color", Color("f2c14e"))
	_caption.add_theme_color_override("font_outline_color", Color.BLACK)
	_caption.add_theme_constant_override("outline_size", 6)
	_caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_caption.visible = false
	add_child(_caption)
	resized.connect(_layout)
	_layout.call_deferred()


## Rect in background pixels -> rect in this control's local coordinates.
func bg_to_local(r: Rect2) -> Rect2:
	var k := maxf(size.x / BG_SIZE.x, size.y / BG_SIZE.y)
	var origin := (size - BG_SIZE * k) / 2.0
	return Rect2(origin + r.position * k, r.size * k)


func stall_rect(cat: String) -> Rect2:
	return bg_to_local(Rect2(STALLS[cat]["rect"]))


func _layout() -> void:
	for cat in _buttons:
		var r := stall_rect(cat)
		_buttons[cat].position = r.position
		_buttons[cat].size = r.size
	_place_caption()


func _on_hover(cat: String, inside: bool) -> void:
	if inside:
		_hover = cat
	elif _hover == cat:
		_hover = ""
	_update_tints()
	_caption.visible = _hover != ""
	if _caption.visible:
		_caption.text = _captions[_hover]
	_place_caption()


func _update_tints() -> void:
	for cat in _buttons:
		_buttons[cat].modulate = HOVER_TINT if cat == _hover or cat == selected else Color.WHITE


func _place_caption() -> void:
	if _caption == null or not _caption.visible:
		return
	_caption.reset_size()
	var r := stall_rect(_hover)
	var x := clampf(r.get_center().x - _caption.size.x / 2.0, 4.0, size.x - _caption.size.x - 4.0)
	# Under the counter: the space above the stalls is taken by the window title.
	_caption.position = Vector2(x, r.end.y + 4.0)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		background_pressed.emit()
