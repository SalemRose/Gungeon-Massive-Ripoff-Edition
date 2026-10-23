class_name SettingsMenu
extends Control
## The SETTINGS screen: resolution, fullscreen, music volume, sfx volume.
## A reusable overlay: the main menu opens it now and the pause menu (13c) will
## too. It only reads and writes the `GameSettings` autoload.
##
##     var menu := SettingsMenu.new()
##     parent.add_child(menu)
##     menu.closed.connect(show_my_buttons_again)
##
## Mouse, keyboard (arrows; left/right change sliders) and gamepad (D-pad)
## all work. Esc / B (ui_cancel) or the Back button closes it.
## Changes apply immediately and are saved by GameSettings.

signal closed

var resolution_option: OptionButton
var fullscreen_check: CheckButton
var music_slider: HSlider
var sfx_slider: HSlider
var back_button: Button


func _ready() -> void:
	# Keep working when opened over a paused game (pause menu).
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var shade := ColorRect.new()
	shade.color = Color(0.07, 0.06, 0.1)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(shade)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	column.custom_minimum_size = Vector2(380.0, 0.0)
	center.add_child(column)

	var title := Label.new()
	title.text = "SETTINGS"
	title.add_theme_font_size_override("font_size", 26)
	title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.35))
	column.add_child(title)

	var settings := _settings()
	resolution_option = OptionButton.new()
	for i in settings.RESOLUTIONS.size():
		resolution_option.add_item(settings.resolution_text(i), i)
	resolution_option.selected = settings.resolution_index
	resolution_option.item_selected.connect(func(i: int): _settings().set_resolution(i))
	_add_row(column, "Resolution", resolution_option)

	fullscreen_check = CheckButton.new()
	fullscreen_check.button_pressed = settings.fullscreen
	fullscreen_check.toggled.connect(func(on: bool): _settings().set_fullscreen(on))
	_add_row(column, "Fullscreen", fullscreen_check)

	music_slider = _make_slider(settings.music_volume, func(v: float): _settings().set_music_volume(v))
	_add_row(column, "Music volume", music_slider)
	sfx_slider = _make_slider(settings.sfx_volume, func(v: float): _settings().set_sfx_volume(v))
	_add_row(column, "SFX volume", sfx_slider)

	back_button = Button.new()
	back_button.text = "Back"
	back_button.custom_minimum_size = Vector2(0.0, 34.0)
	back_button.pressed.connect(close)
	column.add_child(back_button)
	resolution_option.grab_focus.call_deferred()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		close()


func close() -> void:
	closed.emit()
	queue_free()


## One "label ....... control" line.
func _add_row(parent: Control, text: String, control: Control) -> void:
	var row := HBoxContainer.new()
	var label := Label.new()
	label.text = text
	label.custom_minimum_size = Vector2(140.0, 0.0)
	row.add_child(label)
	control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(control)
	parent.add_child(row)


func _make_slider(start: float, on_change: Callable) -> HSlider:
	var slider := HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.05
	slider.value = start
	slider.custom_minimum_size = Vector2(180.0, 24.0)
	slider.value_changed.connect(on_change)
	return slider


## The GameSettings autoload, by path (this class compiles in headless tests).
func _settings() -> Node:
	return get_node("/root/GameSettings")
