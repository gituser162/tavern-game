extends Node
## Autoload "Settings": screen settings (full screen, window size) and the settings panel used by the main menu
## and the pause menu. Music and sound volume live in Audio; the panel shows them too.
## Everything is saved in the same user://settings.cfg as the volume.

const SETTINGS_PATH := "user://settings.cfg"
## Window sizes to choose from (all 16:9, so the 320x180 background scales by whole pixels).
const WINDOW_SIZES: Array[Vector2i] = [Vector2i(1280, 720), Vector2i(1600, 900), Vector2i(1920, 1080), Vector2i(2560, 1440)]

var fullscreen: bool = false
var window_size_index: int = 0
## Save the game by itself every morning.
var autosave: bool = true


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) == OK:
		fullscreen = bool(cfg.get_value("display", "fullscreen", fullscreen))
		window_size_index = clampi(int(cfg.get_value("display", "window_size", window_size_index)), 0, WINDOW_SIZES.size() - 1)
		autosave = bool(cfg.get_value("game", "autosave", autosave))
	_apply_display.call_deferred()


func set_fullscreen(on: bool) -> void:
	fullscreen = on
	_apply_display()
	_save()


func set_window_size(index: int) -> void:
	window_size_index = clampi(index, 0, WINDOW_SIZES.size() - 1)
	_apply_display()
	_save()


func set_autosave(on: bool) -> void:
	autosave = on
	_save()


func _apply_display() -> void:
	# The editor's embedded game window and the headless test runs cannot change the window.
	if DisplayServer.get_name() == "headless" or Engine.is_embedded_in_editor():
		return
	if fullscreen:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		return
	if DisplayServer.window_get_mode() != DisplayServer.WINDOW_MODE_WINDOWED:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	var size: Vector2i = WINDOW_SIZES[window_size_index]
	var screen := DisplayServer.window_get_current_screen()
	var usable := DisplayServer.screen_get_usable_rect(screen)
	# Bigger than the screen: take the biggest size that still fits.
	while (size.x > usable.size.x or size.y > usable.size.y) and size.x > 640:
		size = Vector2i(size.x * 3 / 4, size.y * 3 / 4)
	DisplayServer.window_set_size(size)
	DisplayServer.window_set_position(usable.position + (usable.size - size) / 2)


func _save() -> void:
	var cfg := ConfigFile.new()
	cfg.load(SETTINGS_PATH)
	cfg.set_value("display", "fullscreen", fullscreen)
	cfg.set_value("display", "window_size", window_size_index)
	cfg.set_value("game", "autosave", autosave)
	cfg.save(SETTINGS_PATH)


# ---------- Panel ----------

## Settings panel: music and sound volume, full screen, window size, autosave.
func make_panel() -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	box.custom_minimum_size = Vector2(380, 0)
	box.add_child(_section("Звук"))
	box.add_child(Audio.make_volume_panel())
	box.add_child(_section("Екран"))

	var full := CheckButton.new()
	full.text = "Повний екран"
	full.button_pressed = fullscreen
	full.focus_mode = Control.FOCUS_NONE
	box.add_child(full)

	var size_row := HBoxContainer.new()
	size_row.add_theme_constant_override("separation", 12)
	var size_label := Label.new()
	size_label.text = "Розмір вікна"
	size_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_row.add_child(size_label)
	var sizes := OptionButton.new()
	sizes.focus_mode = Control.FOCUS_NONE
	for s in WINDOW_SIZES:
		sizes.add_item("%d × %d" % [s.x, s.y])
	sizes.select(window_size_index)
	sizes.item_selected.connect(set_window_size)
	sizes.disabled = fullscreen
	size_row.add_child(sizes)
	box.add_child(size_row)
	full.toggled.connect(func(on: bool) -> void:
		set_fullscreen(on)
		sizes.disabled = on)

	box.add_child(_section("Гра"))
	var auto := CheckButton.new()
	auto.text = "Автозбереження щоранку"
	auto.tooltip_text = "Гра зберігається сама на початку кожного дня, а також коли виходиш у меню або закриваєш гру."
	auto.button_pressed = autosave
	auto.focus_mode = Control.FOCUS_NONE
	auto.toggled.connect(set_autosave)
	box.add_child(auto)
	return box


func _section(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_color_override("font_color", Color("f2c14e"))
	l.add_theme_font_size_override("font_size", 17)
	return l
