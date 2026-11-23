extends Node
## Registra las acciones de entrada por código (autoload "GameInput").
##
## Teclado + joystick (PS4, Xbox o cualquier mando compatible con SDL).
## Godot usa la nomenclatura de Xbox: en un PS4, A = Cruz, B = Círculo,
## X = Cuadrado, Y = Triángulo, Back = Share, Start = Options.


func _ready() -> void:
	_action("flipper_left", [
		_key(KEY_Z),
		_key(KEY_SHIFT, KEY_LOCATION_LEFT),
		_button(JOY_BUTTON_LEFT_SHOULDER),       # L1
		_axis(JOY_AXIS_TRIGGER_LEFT, 1.0),       # L2
	])
	_action("flipper_right", [
		_key(KEY_M),
		_key(KEY_SHIFT, KEY_LOCATION_RIGHT),
		_button(JOY_BUTTON_RIGHT_SHOULDER),      # R1
		_axis(JOY_AXIS_TRIGGER_RIGHT, 1.0),      # R2
	])
	_action("launch", [
		_key(KEY_SPACE),
		_key(KEY_ENTER),
		_button(JOY_BUTTON_A),                   # Cruz
	])
	_action("nudge_left", [
		_key(KEY_LEFT),
		_button(JOY_BUTTON_DPAD_LEFT),
		_axis(JOY_AXIS_RIGHT_X, -1.0),
	])
	_action("nudge_right", [
		_key(KEY_RIGHT),
		_button(JOY_BUTTON_DPAD_RIGHT),
		_axis(JOY_AXIS_RIGHT_X, 1.0),
	])
	_action("nudge_up", [
		_key(KEY_UP),
		_button(JOY_BUTTON_DPAD_UP),
		_axis(JOY_AXIS_RIGHT_Y, -1.0),
	])
	_action("restart", [
		_key(KEY_R),
		_button(JOY_BUTTON_START),               # Options
	])
	_action("toggle_panel", [
		_key(KEY_TAB),
		_key(KEY_F1),
		_button(JOY_BUTTON_BACK),                # Share
	])
	_action("debug_drop_ball", [
		_key(KEY_B),
		_button(JOY_BUTTON_Y),                   # Triángulo
	])
	_action("toggle_slowmo", [
		_key(KEY_T),
		_button(JOY_BUTTON_X),                   # Cuadrado
	])


func _action(action_name: String, events: Array) -> void:
	if not InputMap.has_action(action_name):
		InputMap.add_action(action_name, 0.4)
	for ev in events:
		InputMap.action_add_event(action_name, ev)


func _key(keycode: Key, location: KeyLocation = KEY_LOCATION_UNSPECIFIED) -> InputEventKey:
	var ev := InputEventKey.new()
	ev.keycode = keycode
	ev.location = location
	return ev


func _button(index: JoyButton) -> InputEventJoypadButton:
	var ev := InputEventJoypadButton.new()
	ev.button_index = index
	ev.device = -1
	return ev


func _axis(axis: JoyAxis, value: float) -> InputEventJoypadMotion:
	var ev := InputEventJoypadMotion.new()
	ev.axis = axis
	ev.axis_value = value
	ev.device = -1
	return ev
