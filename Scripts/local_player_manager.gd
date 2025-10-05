extends Node

signal player_joined(device_id: int, player_number: int)

var registered_devices: Dictionary = {}  # device_id -> player_number
var registered_input_types: Array = []  # Track if keyboard or joypad joined
var player_count: int = 0
var max_players: int = 2

# Spawn positions for each player
var spawn_positions = [
	Vector2(40, 112),   # Player 1
	Vector2(216, 112)   # Player 2
]

var ready_to_accept_players: bool = false

func _ready():
	# Listen for any input to detect player join
	set_process_input(true)
	# Wait a frame to avoid menu button presses registering as player joins
	await get_tree().process_frame
	ready_to_accept_players = true

func _input(event: InputEvent):
	if not ready_to_accept_players:
		return
		
	# Check for join input (any button press or key)
	if event is InputEventKey:
		if event.pressed and not event.echo:
			print("Key input detected from device: ", event.device)
			_try_register_device(event.device, "keyboard")
	elif event is InputEventJoypadButton:
		if event.pressed:
			print("Joypad button detected from device: ", event.device)
			_try_register_device(event.device, "joypad")

func _try_register_device(device_id: int, input_type: String) -> bool:
	# Create a unique identifier combining device and type
	var unique_id = str(device_id) + "_" + input_type
	
	# Check if this device+type combo is already registered
	if unique_id in registered_devices:
		print("Device ", device_id, " (", input_type, ") already registered")
		return false
	
	# Check if we have room for more players
	if player_count >= max_players:
		print("Max players reached!")
		return false
	
	# Register the device
	player_count += 1
	registered_devices[unique_id] = player_count
	registered_input_types.append(input_type)
	
	print("Player %d joined with device %d (%s)" % [player_count, device_id, input_type])
	print("About to emit signal...")
	player_joined.emit(device_id, player_count)
	print("Signal emitted!")
	
	return true

func get_player_number(device_id: int) -> int:
	return registered_devices.get(device_id, -1)

func get_spawn_position(player_number: int) -> Vector2:
	if player_number > 0 and player_number <= spawn_positions.size():
		return spawn_positions[player_number - 1]
	return Vector2.ZERO

func reset():
	registered_devices.clear()
	player_count = 0
