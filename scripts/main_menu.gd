extends Control
## Main menu (first screen of the game): the tavern at night with the fire burning, a hanging signboard with the
## name and wooden buttons: Продовжити (from the save), Нова гра, Налаштування, Вихід.

const UiStyle := preload("res://scripts/ui_style.gd")
const FireplaceFire := preload("res://scripts/fireplace_fire.gd")
const Wallet := preload("res://scripts/wallet.gd")

const BACKGROUND := "res://assets/backgrounds/tavern.png"
const SIGN := "res://assets/ui/menu_sign.png"
const GAME_SCENE := "res://scenes/main.tscn"
const BG_SIZE := Vector2(320, 180)
## Signboard on the background (bg pixels): hangs from the top edge, over the fireplace wall.
const SIGN_RECT := Rect2(92, 0, 136, 44)
const VERSION := "v0.2"

var _bg: TextureRect
var _sign: TextureRect
var _sign_title: VBoxContainer
var _buttons: VBoxContainer
var _continue: Button
var _save_note: Label
var _settings: Dictionary
var _confirm: Dictionary


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_bg = TextureRect.new()
	_bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_bg.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if ResourceLoader.exists(BACKGROUND):
		_bg.texture = load(BACKGROUND)
	add_child(_bg)
	var fire := FireplaceFire.new()
	fire.setup(_bg)
	add_child(fire)
	# Night: the room is darker, the fire still glows through.
	var night := ColorRect.new()
	night.color = Color(0.02, 0.01, 0.04, 0.5)
	night.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	night.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(night)

	_sign = TextureRect.new()
	_sign.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_sign.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_sign.stretch_mode = TextureRect.STRETCH_SCALE
	_sign.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if ResourceLoader.exists(SIGN):
		_sign.texture = load(SIGN)
	add_child(_sign)
	_sign_title = VBoxContainer.new()
	_sign_title.alignment = BoxContainer.ALIGNMENT_CENTER
	_sign_title.add_theme_constant_override("separation", -6)
	_sign_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_sign_title.add_child(UiStyle.title("Таверна", 22))
	_sign_title.add_child(UiStyle.title("«Втомлений Грифон»", 40))
	add_child(_sign_title)

	_buttons = VBoxContainer.new()
	_buttons.add_theme_constant_override("separation", 10)
	add_child(_buttons)
	_continue = UiStyle.plank_button("Продовжити")
	_continue.pressed.connect(_on_continue)
	_buttons.add_child(_continue)
	_save_note = UiStyle.text_label("", 14, Color("d8c8b0"))
	_save_note.add_theme_color_override("font_outline_color", Color.BLACK)
	_save_note.add_theme_constant_override("outline_size", 5)
	_buttons.add_child(_save_note)
	var new_game := UiStyle.plank_button("Нова гра")
	new_game.pressed.connect(_on_new_game)
	_buttons.add_child(new_game)
	var settings := UiStyle.plank_button("Налаштування")
	settings.pressed.connect(_open_settings)
	_buttons.add_child(settings)
	var quit := UiStyle.plank_button("Вихід")
	quit.pressed.connect(func() -> void: get_tree().quit())
	_buttons.add_child(quit)

	var version := Label.new()
	version.text = VERSION
	version.add_theme_color_override("font_color", Color(1, 1, 1, 0.35))
	version.add_theme_font_size_override("font_size", 13)
	version.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT, Control.PRESET_MODE_MINSIZE, 10)
	add_child(version)

	_build_settings()
	_build_confirm()
	_refresh_save()
	Audio.play_menu_music()
	resized.connect(_place, CONNECT_DEFERRED)
	_place.call_deferred()


func _refresh_save() -> void:
	var info := GameState.save_info()
	_continue.disabled = info.is_empty()
	if info.is_empty():
		_save_note.text = "Збережених ігор немає"
	else:
		_save_note.text = "День %d · %s · %s" % [info["day"], Wallet.format_amount(info["gold"]), String(info["time"]).left(16)]


## Puts the signboard on its background pixels and the buttons under it.
func _place() -> void:
	var scale := maxf(size.x / BG_SIZE.x, size.y / BG_SIZE.y)
	var origin := (size - BG_SIZE * scale) / 2.0
	_sign.position = origin + SIGN_RECT.position * scale
	_sign.size = SIGN_RECT.size * scale
	# Title on the board part (below the chains).
	var board := Rect2(_sign.position + Vector2(2, 11) * scale, Vector2(SIGN_RECT.size.x - 4, 32) * scale)
	_sign_title.position = board.position
	_sign_title.size = board.size
	_buttons.reset_size()
	_buttons.position = Vector2((size.x - _buttons.size.x) / 2.0, _sign.position.y + _sign.size.y + 22.0 * scale / 4.0)


func _on_continue() -> void:
	GameState.start_mode = "load"
	get_tree().change_scene_to_file(GAME_SCENE)


func _on_new_game() -> void:
	if GameState.has_save():
		_confirm["root"].visible = true
		return
	_start_new()


func _start_new() -> void:
	GameState.start_mode = "new"
	get_tree().change_scene_to_file(GAME_SCENE)


# ---------- Windows ----------

func _build_settings() -> void:
	_settings = UiStyle.modal(self)
	var box: VBoxContainer = _settings["box"]
	box.add_child(UiStyle.title("Налаштування"))
	box.add_child(Settings.make_panel())
	var back := UiStyle.plank_button("Назад", 200)
	back.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	back.pressed.connect(_close_windows)
	box.add_child(back)


func _build_confirm() -> void:
	_confirm = UiStyle.modal(self, 460)
	var box: VBoxContainer = _confirm["box"]
	box.add_child(UiStyle.title("Нова гра?", 24))
	box.add_child(UiStyle.text_label("Збережена гра буде замінена новою."))
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 14)
	var yes := UiStyle.plank_button("Почати", 170)
	yes.pressed.connect(_start_new)
	var no := UiStyle.plank_button("Скасувати", 170)
	no.pressed.connect(_close_windows)
	row.add_child(yes)
	row.add_child(no)
	box.add_child(row)


func _open_settings() -> void:
	_settings["root"].visible = true
	Audio.play("open")


func _close_windows() -> void:
	_settings["root"].visible = false
	_confirm["root"].visible = false


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		if _settings["root"].visible or _confirm["root"].visible:
			_close_windows()
			get_viewport().set_input_as_handled()
