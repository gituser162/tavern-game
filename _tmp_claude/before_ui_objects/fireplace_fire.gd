extends Control
## Animated fire in the fireplace on the main background.
## Frames are drawn in the same pixel art as the background (tools: gen_bg4.py + make_fire.py)
## and are laid exactly over the hearth opening; a dithered warm glow flickers over the stones around it.

const FRAMES := "res://assets/objects/fire_frames.png"
const GLOW := "res://assets/objects/fire_glow.png"
const FRAME_COUNT := 12
const FPS := 10.0
## Hearth opening on the background (bg pixels), size of one frame.
const FIRE_RECT := Rect2i(134, 52, 42, 38)
## Glow sprite placement on the background (bg pixels).
const GLOW_RECT := Rect2i(107, 34, 96, 64)
const BG_SIZE := Vector2(320, 180)

var _bg: TextureRect
var _fire: TextureRect
var _atlas: AtlasTexture
var _glow: TextureRect
var _time := 0.0
var _frame := -1


func setup(bg: TextureRect) -> void:
	_bg = bg


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	if ResourceLoader.exists(GLOW):
		_glow = TextureRect.new()
		_glow.texture = load(GLOW)
		_glow.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		_glow.stretch_mode = TextureRect.STRETCH_SCALE
		_glow.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		_glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var mat := CanvasItemMaterial.new()
		mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		_glow.material = mat
		add_child(_glow)
	if ResourceLoader.exists(FRAMES):
		_atlas = AtlasTexture.new()
		_atlas.atlas = load(FRAMES)
		_fire = TextureRect.new()
		_fire.texture = _atlas
		_fire.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		_fire.stretch_mode = TextureRect.STRETCH_SCALE
		_fire.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		_fire.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(_fire)
	_show_frame(0)


func _process(delta: float) -> void:
	_time += delta
	var f := int(_time * FPS) % FRAME_COUNT
	if f != _frame:
		_show_frame(f)
	_place()


func _show_frame(f: int) -> void:
	_frame = f
	if _atlas != null:
		_atlas.region = Rect2(f * FIRE_RECT.size.x, 0, FIRE_RECT.size.x, FIRE_RECT.size.y)
	if _glow != null:
		# Stepped flicker (changes with the frames, not smoothly) keeps the pixel-art feel.
		var t := float(f) / FRAME_COUNT * TAU
		var a := 0.15 + 0.05 * sin(t * 2.0) + 0.03 * sin(t * 3.0 + 1.3)
		_glow.modulate = Color(1, 1, 1, a)


## Same maths as the door/board: the background is scaled to cover the screen.
func _place() -> void:
	if _bg == null:
		return
	var k := maxf(_bg.size.x / BG_SIZE.x, _bg.size.y / BG_SIZE.y)
	var origin := _bg.global_position + (_bg.size - BG_SIZE * k) / 2.0
	if _fire != null:
		_fire.global_position = origin + Vector2(FIRE_RECT.position) * k
		_fire.size = Vector2(FIRE_RECT.size) * k
	if _glow != null:
		_glow.global_position = origin + Vector2(GLOW_RECT.position) * k
		_glow.size = Vector2(GLOW_RECT.size) * k
