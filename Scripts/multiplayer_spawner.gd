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
	print(index)
	match index:
		1:
			player.position = Vector2(30, 112)   # Left side, host
		2:
			player.position = Vector2(226, 112)  # Right side, 1st client
		3:
			player.position = Vector2(30, 112)   # Left side, 2nd client
		4:
			player.position = Vector2(226, 112)  # Right side, 3rd client
		_:
			player.position = Vector2(30, 112)   # fallback
	
	get_node(spawn_path).call_deferred("add_child", player)
	print("Spawned player", id, "at position", player.position)
