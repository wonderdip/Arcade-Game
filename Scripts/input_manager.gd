extends Node

# Stores player input configurations
var player_devices = {} # {player_number: {type: "keyboard"/"controller", device_id: int}}

@export var controller_deadzone: float = 0.2

# For "just pressed" logic on stick up, track previous Y axis value per controller
var last_axis_y := {}

# Registers a player with their input device/type
func register_player(player_number: int, input_type: String, device_id: int = 0):
	player_devices[player_number] = {
		"type": input_type,
		"device_id": device_id
	}
	if input_type == "controller":
		last_axis_y[device_id] = 0.0

# Returns left/right axis for movement
func get_axis(player_number: int, negative: String, positive: String) -> float:
	var device = player_devices.get(player_number, null)
	if device == null:
		return 0.0

	if device.type == "keyboard":
		var suffix = "_" + str(player_number)
		var axis_value = Input.get_axis(negative + suffix, positive + suffix)
		return axis_value

	elif device.type == "controller":
		var joy_axis = Input.get_joy_axis(device.device_id, JOY_AXIS_LEFT_X)
		if abs(joy_axis) > controller_deadzone:
			return joy_axis
		else:
			return 0.0

	else:
		return 0.0

# Returns true if a given action is currently pressed for this player
func is_action_pressed(player_number: int, action: String) -> bool:
	var device = player_devices.get(player_number, null)
	if device == null:
		return false
		
	if device.type == "keyboard":
		var suffix = "_" + str(player_number)
		var pressed = Input.is_action_pressed(action + suffix)
		return pressed
	
	elif device.type == "controller":
		if action == "jump":
			if Input.get_joy_axis(device.device_id, JOY_AXIS_LEFT_Y):
				return true
			else:
				return false
				
		elif action == "hit":
			return Input.is_joy_button_pressed(device.device_id, JOY_BUTTON_B)
			
		elif action == "bump":
			return Input.is_joy_button_pressed(device.device_id, JOY_BUTTON_X)
		
		elif action == "set":
			return Input.is_joy_button_pressed(device.device_id, JOY_BUTTON_A)
			
		elif action == "left":
			var joy_axis = Input.get_joy_axis(device.device_id, JOY_AXIS_LEFT_X)
			if joy_axis < -controller_deadzone:
				return true
			else:
				return false

		elif action == "right":
			var joy_axis = Input.get_joy_axis(device.device_id, JOY_AXIS_LEFT_X)
			if joy_axis > controller_deadzone:
				return true
			else:
				return false
		else:
			return false
	else:
		return false

# Returns true if a given action was just pressed for this player
func is_action_just_pressed(player_number: int, action: String) -> bool:
	var device = player_devices.get(player_number, null)
	if device == null:
		return false

	if device.type == "keyboard":
		var suffix = "_" + str(player_number)
		var just_pressed = Input.is_action_just_pressed(action + suffix)
		return just_pressed

	elif device.type == "controller":
		if action == "jump":
			var current_axis_y = Input.get_joy_axis(device.device_id, JOY_AXIS_LEFT_Y)
			var previous_axis_y = last_axis_y.get(device.device_id, 0.0)
			var axis_just_pressed = previous_axis_y >= -controller_deadzone and current_axis_y < -controller_deadzone
			last_axis_y[device.device_id] = current_axis_y
			
			if axis_just_pressed:
				return true
			else:
				return false

		elif action == "hit":
			var just_pressed_b = Input.is_joy_button_pressed(device.device_id, JOY_BUTTON_B)
			return just_pressed_b

		elif action == "bump":
			var just_pressed_x = Input.is_joy_button_pressed(device.device_id, JOY_BUTTON_X)
			return just_pressed_x

		else:
			return false

	else:
		return false

# Returns the input type for a given player number
func get_device_type(player_number: int) -> String:
	var device = player_devices.get(player_number, null)
	if device == null:
		return ""
	return device.type

# Returns the device ID for a given player number
func get_device_id(player_number: int) -> int:
	var device = player_devices.get(player_number, null)
	if device == null:
		return -1
	return device.device_id

# Clears all player input configuration (call on game reset if needed)
func reset():
	player_devices.clear()
	last_axis_y.clear()
