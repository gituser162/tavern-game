extends Control
## Portrait of the current customer.
## The picture is chosen by GameState when the visitor is created (current_customer["portrait"]):
## by customer type, and for heroes by class; a hero keeps one face for the whole game.
## Pictures live in assets/portraits/, see scripts/portraits.gd for the file naming.

var _cache: Dictionary = {}   # path -> Texture2D
## > 0: small pixel-art pictures are drawn at this whole-number scale (crisp, same pixel size as the room),
## standing on the bottom edge and sunk by `sink` px below it (the control clips them, so the visitor stands behind the counter).
var pixel_scale := 0:
	set(value):
		pixel_scale = value
		queue_redraw()
var sink := 0.0
var _texture: Texture2D

var customer_type: String = "":
	set(value):
		customer_type = value
		_pick_texture()
		queue_redraw()


func _ready() -> void:
	resized.connect(queue_redraw)


func _pick_texture() -> void:
	_texture = null
	if customer_type == "":
		return
	var path: String = GameState.current_customer.get("portrait", "")
	if path == "":
		return
	if not _cache.has(path):
		_cache[path] = load(path) as Texture2D
	_texture = _cache[path]
	# Small pixel-art pictures stay crisp; big painted ones are smoothed.
	var pixel_art := _texture != null and _texture.get_height() <= 256
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST if pixel_art else CanvasItem.TEXTURE_FILTER_LINEAR


func _draw() -> void:
	if _texture == null:
		return
	# Fit inside the control keeping proportions, centred horizontally, standing on the bottom edge.
	var tex_size := _texture.get_size()
	if pixel_scale > 0 and texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST:
		var big := tex_size * pixel_scale
		draw_texture_rect(_texture, Rect2((Vector2((size.x - big.x) / 2.0, size.y - big.y + sink)).floor(), big), false)
		return
	var s := minf(size.x / tex_size.x, size.y / tex_size.y)
	var draw_size := tex_size * s
	var pos := (Vector2((size.x - draw_size.x) / 2.0, size.y - draw_size.y)).floor()
	draw_texture_rect(_texture, Rect2(pos, draw_size), false)
