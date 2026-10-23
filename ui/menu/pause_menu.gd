class_name PauseMenu
extends CanvasLayer
## The PAUSE menu: Esc (keyboard) or Start (gamepad) freezes the game and shows
##   RESUME        back to the game (Esc / B also work)
##   SETTINGS      the same options screen as the main menu
##   ABANDON RUN   give up the run and return to the hub (dungeon only;
##                 the run still pays its currency and counts in your stats)
##   MAIN MENU     back to the title screen
##
## A level adds one in its _ready and listens for abandon:
##
##     var pause := PauseMenu.new()
##     pause.allow_abandon = true
##     pause.abandon_requested.connect(_on_abandon)
##     add_child(pause)
##
## Pausing uses get_tree().paused; this node and the SettingsMenu keep running
## because they have process_mode ALWAYS.

## Emitted when ABANDON RUN is chosen (the level ends the run).
signal abandon_requested
## Emitted instead of changing scene when a test drives the menu directly.
signal scene_requested(path: String)
signal resumed

const MAIN_MENU_SCENE := "res://ui/menu/main_menu.tscn"

## Show the ABANDON RUN button (true in the dungeon, false in the hub).
var allow_abandon: bool = false

var resume_button: Button
var settings_button: Button
var abandon_button: Button
var menu_button: Button

var _root: Control
var _settings_open: bool = false


func _ready() -> void:
	layer = 60
	process_mode = Node.PROCESS_MODE_ALWAYS
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.visible = false
	add_child(_root)
	# Dim the game behind the buttons.
	var shade := ColorRect.new()
	shade.color = Color(0.0, 0.0, 0.0, 0.65)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.add_child(shade)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.add_child(center)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)
	center.add_child(column)
	var title := Label.new()
	title.text = "PAUSED"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.35))
	column.add_child(title)
	resume_button = _add_button(column, "Resume", resume)
	settings_button = _add_button(column, "Settings", _open_settings)
	abandon_button = _add_button(column, "Abandon Run", _on_abandon)
	abandon_button.visible = allow_abandon
	menu_button = _add_button(column, "Main Menu", _on_main_menu)


func is_open() -> bool:
	return _root != null and _root.visible


func _unhandled_input(event: InputEvent) -> void:
	if _settings_open:
		return   # the settings screen handles its own Esc
	if is_open():
		if event.is_action_pressed("pause") or event.is_action_pressed("ui_cancel"):
			get_viewport().set_input_as_handled()
			resume()
	elif event.is_action_pressed("pause") and _can_open():
		get_viewport().set_input_as_handled()
		open()


## Another screen (the unlock shop) may already have paused the game, and a dead
## player should not be able to pause away the death.
func _can_open() -> bool:
	if get_tree().paused:
		return false
	var player := get_tree().get_first_node_in_group("player") as Player
	return player == null or player.state != Player.State.DEAD


func open() -> void:
	_root.visible = true
	get_tree().paused = true
	resume_button.grab_focus.call_deferred()


func resume() -> void:
	if not is_open():
		return
	_root.visible = false
	get_tree().paused = false
	resumed.emit()


func _open_settings() -> void:
	_settings_open = true
	_root.visible = false
	var menu := SettingsMenu.new()
	menu.name = "SettingsMenu"
	menu.closed.connect(func():
		_settings_open = false
		_root.visible = true
		settings_button.grab_focus.call_deferred())
	add_child(menu)


func _on_abandon() -> void:
	get_tree().paused = false
	_root.visible = false
	abandon_requested.emit()


func _on_main_menu() -> void:
	get_tree().paused = false
	_root.visible = false
	# Leaving mid-run drops the run without a payout (use Abandon Run for that).
	get_node("/root/Run").reset()
	if get_tree().current_scene != null:
		get_tree().change_scene_to_file(MAIN_MENU_SCENE)
	else:
		scene_requested.emit(MAIN_MENU_SCENE)


func _add_button(parent: Control, text: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(260.0, 34.0)
	button.pressed.connect(callback)
	parent.add_child(button)
	return button
