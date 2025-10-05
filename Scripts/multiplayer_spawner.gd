extends MultiplayerSpawner

@export var network_player: PackedScene

func _ready() -> void:
	# Only run in network mode
	if Networkhandler.is_local:
		print("Local mode - skipping multiplayer spawner")
		return
	
	# Spawn server's own player immediately
	if multiplayer.is_server():
		call_deferred("spawn_player", 1)
	
	# Connect to spawn other players when they join
	multiplayer.peer_connected.connect(spawn_player)
	
func spawn_player(id: int) -> void:
	if !multiplayer.is_server(): 
		return
	
	print("Spawning player with ID: ", id)
	
	var player: Node = network_player.instantiate()
	player.name = str(id)
	
	# Position players on their respective sides
	if id == 1:
		player.position = Vector2(40, 112)  # Left side (server)
	else:
		player.position = Vector2(216, 112)  # Right side (client)
	
	get_node(spawn_path).add_child(player, true)
