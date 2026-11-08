extends Button
## Contract board hanging on the tavern wall. The board itself (frame and cork) is part of the
## background picture; this button lies exactly over it and pins one paper note per contract
## that is on offer today, so the player sees at a glance how many contracts there are.
## Notes are drawn in background pixels (RECT is in tavern.png pixels) and scaled with the background.

## Board in tavern.png pixels: frame 54..87 x 28..66 plus the small header plank above it.
const RECT := Rect2i(54, 24, 33, 44)
## Note size and where notes are pinned (relative to RECT, in background pixels).
const NOTE := Vector2i(12, 14)
const SPOTS := [Vector2i(3, 7), Vector2i(17, 8), Vector2i(4, 23), Vector2i(17, 22), Vector2i(10, 15), Vector2i(11, 4)]
## Colours are already darkened to match the lighting of the background.
const PAPER := Color("cdbd96")
const PAPER_DARK := Color("a8976e")
const INK := Color("6e5e44")
const SHADOW := Color(0.08, 0.05, 0.03, 0.55)
## Pin colour shows the difficulty of the contract.
const PIN_COLORS := {"easy": Color("7fb04f"), "medium": Color("e0b840"), "hard": Color("c8402e")}

## Tier id of every note on the board ("easy", "medium", "hard").
var tiers: Array = []:
	set(value):
		tiers = value
		queue_redraw()


func _init() -> void:
	flat = true
	focus_mode = Control.FOCUS_NONE
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	# The button draws nothing itself: no hover or pressed boxes over the background.
	var empty := StyleBoxEmpty.new()
	for state in ["normal", "hover", "pressed", "disabled", "focus", "hover_pressed"]:
		add_theme_stylebox_override(state, empty)
	mouse_entered.connect(_on_hover.bind(true))
	mouse_exited.connect(_on_hover.bind(false))


func _on_hover(inside: bool) -> void:
	# Same hover look as the mortar and the door: the object lights up.
	modulate = Color(1.3, 1.22, 0.95) if inside else Color.WHITE


func _draw() -> void:
	var k := size.x / RECT.size.x
	for i in mini(tiers.size(), SPOTS.size()):
		_draw_note(SPOTS[i], String(tiers[i]), i, k)


func _draw_note(at: Vector2i, tier: String, index: int, k: float) -> void:
	var p := func(x: int, y: int, w: int, h: int, c: Color) -> void:
		draw_rect(Rect2(Vector2(at.x + x, at.y + y) * k, Vector2(w, h) * k), c)
	var w := NOTE.x
	var h := NOTE.y - (index % 2)  # notes are not all the same, so the board looks hand-filled
	p.call(1, 1, w, h, SHADOW)
	p.call(0, 0, w, h, PAPER)
	p.call(0, h - 1, w, 1, PAPER_DARK)
	p.call(w - 1, 0, 1, h, PAPER_DARK)
	# folded lower corner
	p.call(w - 3, h - 3, 3, 3, PAPER_DARK)
	p.call(w - 2, h - 2, 2, 2, SHADOW)
	# heading and text lines
	p.call(2, 3, w - 5, 1, INK)
	for ly in range(6, h - 2, 2):
		var lw := w - 4 - ((ly + index) % 3)
		p.call(2, ly, lw, 1, INK.lerp(PAPER, 0.35))
	# pin (colour = difficulty)
	var pin: Color = PIN_COLORS.get(tier, Color("b0b0b8"))
	p.call(w / 2 - 1, -1, 2, 2, pin)
	p.call(w / 2 - 1, -1, 1, 1, pin.lightened(0.45))
