extends MultiplayerSpawner

@export var network_player: PackedScene
var player_count := 0

# Define spawn positions
var spawn_positions = {
	1: Vector2(30, 112),   # Host/Player 1
	2: Vector2(226, 112),  # First client/Player 2
	3: Vector2(30, 112),   # Second client/Player 3
	4: Vector2(226, 112)   # Third client/Player 4
}

func _ready() -> void:
	if Networkhandler.is_local:
		return
	
	# Only server handles spawning
	if not multiplayer.is_server():
		return
	
	# Wait a frame before spawning to avoid "parent busy" error
	await get_tree().process_frame
	
	# Spawn host player
	_on_peer_connected(multiplayer.get_unique_id())
	
	# Connect to handle client connections
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
func _on_peer_connected(id: int) -> void:
	if not multiplayer.is_server():
		return
	
	player_count += 1
	spawn_player(id, player_count)
	
func _on_peer_disconnected(id: int) -> void:
	if not multiplayer.is_server():
		return
	
	print("Peer disconnected:", id)
	
	# Find and remove that player's node
	var player_node := get_tree().get_root().find_child(str(id), true, false)
	if player_node:
		player_node.queue_free()
		print("Removed player for peer ID:", id)
	
	player_count -= 1

	
func spawn_player(id: int, index: int) -> void:
	# Create player instance
	var player: CharacterBody2D = network_player.instantiate() as CharacterBody2D
	
	#Set the name to the peer ID so clients know who owns this player
	player.name = str(id)
	# Get spawn position
	var spawn_pos: Vector2 = spawn_positions.get(index, Vector2(30, 112))
	var parent: Node = get_node(spawn_path)
	parent.add_child(player, true)
	
	player.player_number = index
	player.position = spawn_pos
	
