extends Node

signal player_joined(device_id: int, player_number: int, input_type: String)

var registered_devices: Array = []  # List of {device_id, input_type} dictionaries
var player_count: int = 0
var max_players: int = 2

# Spawn positions for each player
var spawn_positions = [
	Vector2(40, 112),   # Player 1
	Vector2(216, 112),   # Player 2
	Vector2(40, 112),
	Vector2(216, 112)
]

var ready_to_accept_players: bool = false
var keyboard_count: int = 0
var controller_count: int = 0
var player_1_actions: Array = ["bump_1", "hit_1", "jump_1", "left_1", "right_1"]
var player_2_actions: Array = ["bump_2", "hit_2", "jump_2", "left_2", "right_2"]


func _ready():
	set_process_input(true)
	await get_tree().process_frame

func _input(event: InputEvent):
	if not ready_to_accept_players or player_count >= max_players:
		return

	# Register Player 1
	if player_count == 0:
		# Controller registration
		if event is InputEventJoypadButton and event.pressed:
			_try_register_device(event.device, "controller")
			print("Player 1 registered with controller")
			return # Prevent further registration this frame
		elif event is InputEventJoypadMotion and abs(event.axis_value) > 0.5:
			_try_register_device(event.device, "controller")
			print("Player 1 registered with controller (motion)")
			return
		
		# Keyboard registration
		for action in player_1_actions:
			if event.is_action_pressed(action):
				_try_register_device(event.device, "keyboard")
				print("Player 1 registered with keyboard")
				return

	# Register Player 2
	elif player_count == 1:
		# Controller registration
		if event is InputEventJoypadButton and event.pressed:
			_try_register_device(event.device, "controller")
			print("Player 2 registered with controller", event.device)
			return
		elif event is InputEventJoypadMotion and abs(event.axis_value) > 0.5:
			_try_register_device(event.device, "controller")
			print("Player 2 registered with controller (motion)")
			return

		# Keyboard registration
		for action in player_2_actions:
			if event.is_action_pressed(action):
				_try_register_device(event.device, "keyboard")
				print("Player 2 registered with keyboard", event.device)
				return

func _try_register_device(device_id: int, input_type: String) -> bool:
	# For keyboard, allow up to 2 players
	if input_type == "keyboard":
		if keyboard_count >= 2:
			print("Already have 2 keyboard players")
			return false
		keyboard_count += 1
	else:
		# For controllers, check if this specific device is already registered
		for registered in registered_devices:
			if registered.device_id == device_id and registered.input_type == "controller":
				print("Controller device ", device_id, " already registered")
				return false
		controller_count += 1
	
	# Register the device
	player_count += 1
	registered_devices.append({"device_id": device_id, "input_type": input_type, "player_number": player_count})
	
	var device_name = "keyboard" if input_type == "keyboard" else ("controller " + str(device_id))
	print("Player ", player_count, " joined with ", device_name)
	
	emit_signal("player_joined", device_id, player_count, input_type)
	
	return true

func get_spawn_position(player_number: int) -> Vector2:
	if player_number > 0 and player_number <= spawn_positions.size():
		return spawn_positions[player_number - 1]
	return Vector2.ZERO

func reset():
	registered_devices.clear()
	player_count = 0
	keyboard_count = 0
	controller_count = 0
	ready_to_accept_players = false
