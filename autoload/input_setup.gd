extends Node
## Registers every input action in code (autoload "InputSetup").
##
## WHY CODE AND NOT THE EDITOR'S INPUT MAP?
## One readable table is easier to review and extend than the project.godot
## input format. Keyboard/mouse AND gamepad bindings for an action sit side by
## side here. If you prefer the editor UI later, delete the actions you want to
## edit from this table and add them in Project Settings > Input Map.
##
## Gameplay code never mentions a key or a button, only an action name:
##     Input.is_action_just_pressed("dodge")
## so rebinding or new devices never touch gameplay scripts.

const STICK_DEADZONE := 0.2
const TRIGGER_DEADZONE := 0.4


func _ready() -> void:
	# --- Movement: WASD / arrows / left stick ---------------------------------
	_register("move_up", [_key(KEY_W), _key(KEY_UP), _pad_axis(JOY_AXIS_LEFT_Y, -1.0)])
	_register("move_down", [_key(KEY_S), _key(KEY_DOWN), _pad_axis(JOY_AXIS_LEFT_Y, 1.0)])
	_register("move_left", [_key(KEY_A), _key(KEY_LEFT), _pad_axis(JOY_AXIS_LEFT_X, -1.0)])
	_register("move_right", [_key(KEY_D), _key(KEY_RIGHT), _pad_axis(JOY_AXIS_LEFT_X, 1.0)])

	# --- Aiming: right stick only (the mouse is read directly in player.gd) ---
	_register("aim_up", [_pad_axis(JOY_AXIS_RIGHT_Y, -1.0)])
	_register("aim_down", [_pad_axis(JOY_AXIS_RIGHT_Y, 1.0)])
	_register("aim_left", [_pad_axis(JOY_AXIS_RIGHT_X, -1.0)])
	_register("aim_right", [_pad_axis(JOY_AXIS_RIGHT_X, 1.0)])

	# --- Combat ---------------------------------------------------------------
	_register("shoot", [_mouse(MOUSE_BUTTON_LEFT), _pad_axis(JOY_AXIS_TRIGGER_RIGHT, 1.0)], TRIGGER_DEADZONE)
	_register("dodge", [_key(KEY_SPACE), _mouse(MOUSE_BUTTON_RIGHT), _pad_button(JOY_BUTTON_A)])
	_register("melee", [_key(KEY_F), _pad_button(JOY_BUTTON_RIGHT_SHOULDER)])
	_register("blank", [_key(KEY_Q), _pad_button(JOY_BUTTON_LEFT_SHOULDER)])
	_register("reload", [_key(KEY_R), _pad_button(JOY_BUTTON_X)])

	# --- World / inventory ----------------------------------------------------
	_register("interact", [_key(KEY_E), _pad_button(JOY_BUTTON_Y)])
	_register("weapon_next", [_mouse(MOUSE_BUTTON_WHEEL_DOWN), _pad_button(JOY_BUTTON_DPAD_RIGHT)])
	_register("weapon_prev", [_mouse(MOUSE_BUTTON_WHEEL_UP), _pad_button(JOY_BUTTON_DPAD_LEFT)])
	_register("pause", [_key(KEY_ESCAPE), _pad_button(JOY_BUTTON_START)])


## Creates (or replaces) one action with all of its input events.
func _register(action: String, events: Array[InputEvent], deadzone: float = STICK_DEADZONE) -> void:
	if InputMap.has_action(action):
		InputMap.erase_action(action)
	InputMap.add_action(action, deadzone)
	for event in events:
		InputMap.action_add_event(action, event)


## physical_keycode = the key's POSITION on the keyboard, so WASD works on
## QWERTY, AZERTY, etc. without the player rebinding anything.
func _key(keycode: Key) -> InputEventKey:
	var event := InputEventKey.new()
	event.physical_keycode = keycode
	return event


func _mouse(button: MouseButton) -> InputEventMouseButton:
	var event := InputEventMouseButton.new()
	event.button_index = button
	return event


func _pad_button(button: JoyButton) -> InputEventJoypadButton:
	var event := InputEventJoypadButton.new()
	event.button_index = button
	return event


## direction is -1.0 or +1.0: which way along the axis triggers the action.
func _pad_axis(axis: JoyAxis, direction: float) -> InputEventJoypadMotion:
	var event := InputEventJoypadMotion.new()
	event.axis = axis
	event.axis_value = direction
	return event
