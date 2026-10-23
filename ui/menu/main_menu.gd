extends Control
## The MAIN MENU: the first screen of the game.
##   NEW GAME  starts a fresh save (asks first if there is progress to lose)
##   LOAD      continues with the saved progress (greyed out if there is none)
##   SETTINGS  options screen (resolution, fullscreen, volumes: SettingsMenu)
##   QUIT      exits
##
## Works with mouse, keyboard (arrows + Enter) and gamepad (D-pad + A).
## Everything is built in code from plain Controls, so restyling it later means
## giving the nodes a Theme or replacing the title Label with a logo texture.
##
## The save is a single slot: it holds the permanent progress (currency,
## unlocks, stats) kept by the SaveData autoload.

## Emitted instead of changing scene when a test drives the menu directly.
signal scene_requested(path: String)
signal settings_opened

const HUB_SCENE := "res://levels/hub/hub.tscn"
const TITLE := "GUNGEON\nMASSIVE RIPOFF EDITION"

var new_game_button: Button
var load_button: Button
var settings_button: Button
var quit_button: Button

var _menu_box: VBoxContainer
var _confirm_box: VBoxContainer
var _note: Label


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var background := ColorRect.new()
	background.color = Color(0.07, 0.06, 0.1)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 14)
	center.add_child(column)

	var title := Label.new()
	title.name = "Title"
	title.text = TITLE
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 34)
	title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.35))
	column.add_child(title)

	# The four main buttons.
	_menu_box = VBoxContainer.new()
	_menu_box.add_theme_constant_override("separation", 6)
	column.add_child(_menu_box)
	new_game_button = _add_button(_menu_box, "New Game", _on_new_game)
	load_button = _add_button(_menu_box, "Load", _on_load)
	settings_button = _add_button(_menu_box, "Settings", _on_settings)
	quit_button = _add_button(_menu_box, "Quit", _on_quit)
	load_button.disabled = not _save().has_progress()

	# "Erase your progress?" question, shown in place of the buttons.
	_confirm_box = VBoxContainer.new()
	_confirm_box.visible = false
	_confirm_box.add_theme_constant_override("separation", 6)
	column.add_child(_confirm_box)
	var question := Label.new()
	question.text = "Starting a new game erases your saved progress.\nContinue?"
	question.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_confirm_box.add_child(question)
	_add_button(_confirm_box, "Yes, erase and start", _start_fresh).name = "ConfirmYes"
	_add_button(_confirm_box, "No, go back", _close_confirm).name = "ConfirmNo"

	_note = Label.new()
	_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_note.add_theme_font_size_override("font_size", 12)
	column.add_child(_note)

	_focus_main()


func _unhandled_input(event: InputEvent) -> void:
	# Esc / B backs out of the confirmation question.
	if _confirm_box.visible and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_close_confirm()


func _add_button(parent: Control, text: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(260.0, 34.0)
	button.pressed.connect(callback)
	parent.add_child(button)
	return button


## The save node, looked up by path so this script compiles in headless tests.
func _save() -> Node:
	return get_node("/root/SaveData")


func _focus_main() -> void:
	_note.text = ""
	# New Game is always enabled, so there is always something to focus.
	new_game_button.grab_focus.call_deferred()


# --- Button handlers ----------------------------------------------------------

func _on_new_game() -> void:
	if _save().has_progress():
		_menu_box.visible = false
		_confirm_box.visible = true
		(_confirm_box.get_node("ConfirmNo") as Button).grab_focus.call_deferred()
	else:
		_start_fresh()


func _close_confirm() -> void:
	_confirm_box.visible = false
	_menu_box.visible = true
	_focus_main()


func _start_fresh() -> void:
	_save().reset_all()
	_go(HUB_SCENE)


func _on_load() -> void:
	if _save().has_progress():
		_go(HUB_SCENE)


## Shows the settings screen over the menu; the menu buttons come back when it closes.
func _on_settings() -> void:
	_menu_box.visible = false
	var menu := SettingsMenu.new()
	menu.name = "SettingsMenu"
	menu.closed.connect(func():
		_menu_box.visible = true
		settings_button.grab_focus.call_deferred())
	add_child(menu)
	settings_opened.emit()


func _on_quit() -> void:
	get_tree().quit()


func _go(path: String) -> void:
	if get_tree().current_scene != null:
		get_tree().change_scene_to_file(path)
	else:
		scene_requested.emit(path)
