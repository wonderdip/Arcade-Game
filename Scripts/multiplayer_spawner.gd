extends MultiplayerSpawner

@export var network_player: PackedScene
var player_count := 0

func _ready() -> void:
	if Networkhandler.is_local:
		return
	
	if multiplayer.is_server():
		_on_peer_connected(multiplayer.get_unique_id()) # Spawn host player
	
	multiplayer.peer_connected.connect(_on_peer_connected)

func _on_peer_connected(id: int) -> void:
	if !multiplayer.is_server():
		return
	
	player_count += 1
	spawn_player(id, player_count)

func spawn_player(id: int, index: int) -> void:
	var player: Node = network_player.instantiate()
	player.name = str(id)

	# --- 1) Assign authority on the instance BEFORE it enters the scene tree.
	# This must be executed on the server only.
	if multiplayer.is_server():
		player.set_multiplayer_authority(id)
		print("Spawner: set authority", id, "on instance", player.name)

	# --- 2) Set any properties that must be replicated at spawn BEFORE add_child.
	# Ensure player_number is included in the Player scene's SceneReplicationConfig.
	player.player_number = index

	# Choose spawn position (use global_position to avoid parent-space ambiguity).
	var spawn_pos := Vector2.ZERO
	match index:
		1:
			spawn_pos = Vector2(30, 112)   # Left side, host
		2:
			spawn_pos = Vector2(226, 112)  # Right side, 1st client
		3:
			spawn_pos = Vector2(30, 112)   # Left side, 2nd client
		4:
			spawn_pos = Vector2(226, 112)  # Right side, 3rd client
		_:
			spawn_pos = Vector2(30, 112)   # fallback

	player.global_position = spawn_pos

	# --- 3) Add to the tree after authority + properties are set.
	# Use call_deferred with the method name (string) to avoid
	# "Parent node is busy setting up children" errors.
	get_node(spawn_path).call_deferred("add_child", player)

	print("Spawner: Spawned player", id, "at position", player.global_position, "player_number=", player.player_number)
