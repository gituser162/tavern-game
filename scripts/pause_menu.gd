extends Control
## Game menu over the tavern (Esc or the "Меню" button in the top bar). The game is paused while it is open.
## Продовжити, Зберегти гру, Завантажити, Налаштування, Головне меню, Вихід.

const UiStyle := preload("res://scripts/ui_style.gd")
const Wallet := preload("res://scripts/wallet.gd")
const MENU_SCENE := "res://scenes/menu.tscn"
const GAME_SCENE := "res://scenes/main.tscn"

var _main: Dictionary
var _settings: Dictionary
var _save_button: Button
var _load_button: Button
var _note: Label


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 50
	_main = UiStyle.modal(self, 380)
	var box: VBoxContainer = _main["box"]
	box.add_child(UiStyle.title("Меню"))
	var buttons := [
		["Продовжити", close],
		["Зберегти гру", _on_save],
		["Завантажити", _on_load],
		["Налаштування", _open_settings],
		["Головне меню", _on_main_menu],
		["Вийти з гри", _on_quit],
	]
	for entry in buttons:
		var b := UiStyle.plank_button(entry[0], 320)
		b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		b.pressed.connect(entry[1])
		box.add_child(b)
		if entry[0] == "Зберегти гру":
			_save_button = b
		elif entry[0] == "Завантажити":
			_load_button = b
	_note = UiStyle.text_label("", 14, Color("b8a48c"))
	_note.custom_minimum_size = Vector2(320, 0)
	box.add_child(_note)

	_settings = UiStyle.modal(self)
	var sbox: VBoxContainer = _settings["box"]
	sbox.add_child(UiStyle.title("Налаштування"))
	sbox.add_child(Settings.make_panel())
	var back := UiStyle.plank_button("Назад", 200)
	back.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	back.pressed.connect(_close_settings)
	sbox.add_child(back)


func is_open() -> bool:
	return _main["root"].visible or _settings["root"].visible


func open() -> void:
	_settings["root"].visible = false
	_main["root"].visible = true
	_refresh("")
	get_tree().paused = true
	Audio.play("open")


func close() -> void:
	_main["root"].visible = false
	_settings["root"].visible = false
	get_tree().paused = false


func _refresh(message: String) -> void:
	var problem := GameState.save_problem()
	_save_button.disabled = problem != ""
	_save_button.tooltip_text = problem
	var info := GameState.save_info()
	_load_button.disabled = info.is_empty()
	if message != "":
		_note.text = message
	elif problem != "":
		_note.text = problem
	elif info.is_empty():
		_note.text = "Гру ще не збережено."
	else:
		_note.text = "Останнє збереження: день %d, %s." % [info["day"], String(info["time"]).substr(11, 5)]


func _on_save() -> void:
	if GameState.save_game():
		Audio.play("coin")
		_refresh("Гру збережено.")
	else:
		Audio.play("error")
		_refresh("Не вдалося зберегти гру.")


## Back to the last save (manual or the morning autosave): the game screen starts again from the file.
func _on_load() -> void:
	if not GameState.has_save():
		return
	get_tree().paused = false
	GameState.start_mode = "load"
	get_tree().reload_current_scene()


func _on_main_menu() -> void:
	_autosave()
	get_tree().paused = false
	get_tree().change_scene_to_file(MENU_SCENE)


func _on_quit() -> void:
	_autosave()
	get_tree().quit()


## Leaving the game keeps the progress (if autosave is on and the keeper is in the tavern).
func _autosave() -> void:
	if Settings.autosave and GameState.can_save():
		GameState.save_game()


func _open_settings() -> void:
	_main["root"].visible = false
	_settings["root"].visible = true


func _close_settings() -> void:
	_settings["root"].visible = false
	_main["root"].visible = true


func _unhandled_input(event: InputEvent) -> void:
	if not is_open():
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		if _settings["root"].visible:
			_close_settings()
		else:
			close()
		get_viewport().set_input_as_handled()
