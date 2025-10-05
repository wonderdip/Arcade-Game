extends Node

signal player_joined(device_id: int, player_number: int)

var registered_devices: Dictionary = {}  # device_id -> player_number
var player_count: int = 0
var max_players: int = 2

# Spawn positions for each player
var spawn_positions = [
	Vector2(40, 112),   # Player 1
	Vector2(216, 112)   # Player 2
]

func _ready():
	# Listen for any input to detect player join
	set_process_input(true)

func _input(event: InputEvent):
	# Check for join input (any button press or key)
	if event is InputEventKey or event is InputEventJoypadButton:
		if event.pressed and not event.echo:
			_try_register_device(event.device)

func _try_register_device(device_id: int) -> bool:
	# Check if already registered
	if device_id in registered_devices:
		return false
	
	# Check if we have room for more players
	if player_count >= max_players:
		print("Max players reached!")
		return false
	
	# Register the device
	player_count += 1
	registered_devices[device_id] = player_count
	
	print("Player %d joined with device %d" % [player_count, device_id])
	emit_signal("player_joined", device_id, player_count)
	
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
