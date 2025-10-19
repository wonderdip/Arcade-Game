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

func _on_peer_connected(id: int) -> void:
	if not multiplayer.is_server():
		return
	
	player_count += 1
	print("Spawner: Peer %d connected, assigning player number %d" % [id, player_count])
	spawn_player(id, player_count)

func spawn_player(id: int, index: int) -> void:
	# Create player instance
	var player: CharacterBody2D = network_player.instantiate() as CharacterBody2D
	
	# CRITICAL: Set the name to the peer ID so clients know who owns this player
	player.name = str(id)
	
	# Get spawn position
	var spawn_pos: Vector2 = spawn_positions.get(index, Vector2(30, 112))
	
	print("Spawner: Creating player %d at position %v for peer %d" % [index, spawn_pos, id])
	
	# Add to tree FIRST - MultiplayerSpawner will handle replication
	var parent: Node = get_node(spawn_path)
	parent.add_child(player, true)
	
	# Set properties AFTER adding to tree so they're properly synced
	player.player_number = index
	player.position = spawn_pos
	
	print("Spawner: Player %d spawned at %v, name=%s, player_number=%d" % [index, spawn_pos, player.name, player.player_number])
