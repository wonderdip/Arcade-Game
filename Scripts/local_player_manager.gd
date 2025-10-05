extends Node

signal player_joined(device_id: int, player_number: int, input_type: String)

var registered_devices: Array = []  # List of {device_id, input_type} dictionaries
var player_count: int = 0
var max_players: int = 2

# Spawn positions for each player
var spawn_positions = [
	Vector2(40, 112),   # Player 1
	Vector2(216, 112)   # Player 2
]

var ready_to_accept_players: bool = false
var keyboard_count: int = 0
var controller_count: int = 0

func _ready():
	set_process_input(true)
	await get_tree().process_frame
	ready_to_accept_players = true
	print("LocalPlayerManager ready!")
	print("Press any key/button to join as Player 1")
	print("Then press another key/button to join as Player 2")

func _input(event: InputEvent):
	if not ready_to_accept_players:
		return
	
	if player_count >= max_players:
		return
	
	# Detect keyboard input
	if event is InputEventKey and event.pressed and not event.echo:
		_try_register_device(0, "keyboard")
	
	# Detect joypad input
	elif event is InputEventJoypadButton and event.pressed:
		_try_register_device(event.device, "controller")

func _try_register_device(device_id: int, input_type: String) -> bool:
	# Check if this device+type combo is already registered
	for registered in registered_devices:
		if registered.device_id == device_id and registered.input_type == input_type:
			print("Device ", device_id, " (", input_type, ") already registered")
			return false
	
	# Special handling for keyboard - allow 2 keyboard players
	if input_type == "keyboard":
		if keyboard_count >= 2:
			print("Already have 2 keyboard players")
			return false
		keyboard_count += 1
	else:
		# For controllers, each device can only register once
		controller_count += 1
	
	# Register the device
	player_count += 1
	registered_devices.append({"device_id": device_id, "input_type": input_type, "player_number": player_count})
	
	var device_name = "keyboard" if input_type == "keyboard" else ("controller " + str(device_id))
	print("Player ", player_count, " joined with ", device_name)
	
	player_joined.emit(device_id, player_count, input_type)
	
	if player_count < max_players:
		print("Waiting for Player ", player_count + 1, " to join...")
	else:
		print("Both players joined! Starting game...")
	
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
