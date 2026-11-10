extends Control
## Contract board hanging on the tavern wall. The board itself (frame and cork) is part of the
## background picture; this control lies exactly over it and pins one paper note per contract
## that is on offer today, so the player sees at a glance how many contracts there are.
## Hovering a note asks main.gd for its tooltip, clicking a note reports which one was clicked.
## Notes are drawn in background pixels (RECT is in tavern.png pixels) and scaled with the background.

signal note_hovered(index: int)  ## -1 when the mouse is not over any note
signal note_pressed(index: int)

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
## Criminal orders are written on dark, soot-stained paper; state contracts carry a blue wax seal.
const CRIME_PAPER := Color("5a4a52")
const CRIME_PAPER_DARK := Color("43363d")
const CRIME_INK := Color("1e161b")
const SEAL := Color("3f68a8")

## Tier id of every note on the board ("easy", "medium", "hard").
var tiers: Array = []:
	set(value):
		tiers = value
		if hovered >= tiers.size():
			hovered = -1
		queue_redraw()
## Who gives every note: "people", "state" or "crime" (see GameData.CONTRACT_FACTIONS).
var kinds: Array = []:
	set(value):
		kinds = value
		queue_redraw()
## Notes drawn faded (e.g. contracts the hero at the counter refuses).
var faded: Array = []:
	set(value):
		faded = value
		queue_redraw()
## Notes can be clicked (a hero is waiting for a contract).
var clickable := false:
	set(value):
		clickable = value
		_update_cursor()
var hovered := -1


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	mouse_exited.connect(_set_hovered.bind(-1))


func note_at(local: Vector2) -> int:
	var k := size.x / RECT.size.x
	var p := local / k
	# Later notes are drawn on top, so check them first.
	for i in range(mini(tiers.size(), SPOTS.size()) - 1, -1, -1):
		if Rect2(Vector2(SPOTS[i]) - Vector2(0, 1), Vector2(NOTE) + Vector2(1, 2)).has_point(p):
			return i
	return -1


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		_set_hovered(note_at(event.position))
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var i := note_at(event.position)
		if i >= 0:
			note_pressed.emit(i)
			accept_event()


func _set_hovered(i: int) -> void:
	if i == hovered:
		return
	hovered = i
	_update_cursor()
	queue_redraw()
	note_hovered.emit(i)


func _update_cursor() -> void:
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if clickable and hovered >= 0 else Control.CURSOR_ARROW


func _draw() -> void:
	var k := size.x / RECT.size.x
	for i in mini(tiers.size(), SPOTS.size()):
		_draw_note(SPOTS[i], String(tiers[i]), i, k, String(kinds[i]) if i < kinds.size() else "people")


func _draw_note(at: Vector2i, tier: String, index: int, k: float, kind: String = "people") -> void:
	var paper := CRIME_PAPER if kind == "crime" else PAPER
	var paper_dark := CRIME_PAPER_DARK if kind == "crime" else PAPER_DARK
	var ink := CRIME_INK if kind == "crime" else INK
	# Hovered note lights up and lifts a little, like the other objects in the room.
	var lit := index == hovered
	var tint := Color(1.25, 1.2, 1.0) if lit else Color.WHITE
	if index < faded.size() and faded[index]:
		tint = Color(0.62, 0.58, 0.55) if not lit else Color(0.8, 0.75, 0.7)
	var lift := Vector2(0, -1) if lit else Vector2.ZERO
	var p := func(x: int, y: int, w: int, h: int, c: Color, shadow: bool = false) -> void:
		var o := Vector2(at.x + x, at.y + y) + (Vector2.ZERO if shadow else lift)
		draw_rect(Rect2(o * k, Vector2(w, h) * k), c if shadow else c * tint)
	var w := NOTE.x
	var h := NOTE.y - (index % 2)  # notes are not all the same, so the board looks hand-filled
	p.call(1, 1, w, h, SHADOW, true)
	p.call(0, 0, w, h, paper)
	p.call(0, h - 1, w, 1, paper_dark)
	p.call(w - 1, 0, 1, h, paper_dark)
	# folded lower corner
	p.call(w - 3, h - 3, 3, 3, paper_dark)
	p.call(w - 2, h - 2, 2, 2, SHADOW.darkened(0.2))
	# heading and text lines
	p.call(2, 3, w - 5, 1, ink)
	for ly in range(6, h - 2, 2):
		var lw := w - 4 - ((ly + index) % 3)
		p.call(2, ly, lw, 1, ink.lerp(paper, 0.35))
	# pin (colour = difficulty)
	var pin: Color = PIN_COLORS.get(tier, Color("b0b0b8"))
	p.call(w / 2 - 1, -1, 2, 2, pin)
	p.call(w / 2 - 1, -1, 1, 1, pin.lightened(0.45))
	if kind == "state":
		# a blue wax seal in the lower left corner
		p.call(1, h - 4, 3, 3, SEAL)
		p.call(1, h - 4, 1, 1, SEAL.lightened(0.4))
	elif kind == "crime":
		# a dark red X instead of a heading
		p.call(w - 5, 2, 1, 1, Color("8a2a2a"))
		p.call(w - 3, 2, 1, 1, Color("8a2a2a"))
		p.call(w - 4, 3, 1, 1, Color("8a2a2a"))
		p.call(w - 5, 4, 1, 1, Color("8a2a2a"))
		p.call(w - 3, 4, 1, 1, Color("8a2a2a"))
