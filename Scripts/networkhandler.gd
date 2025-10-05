extends Node

const DEFAULT_PORT: int = 41677
var MAX_CLIENTS: int = 2

var peer: ENetMultiplayerPeer
var is_local: bool = false
var server_name: String = ""

func start_server(server_name_param: String = "", port: int = 0) -> void:
	if server_name_param != "":
		server_name = server_name_param
	if port == 0:
		port = randi_range(20000, 60000)
	peer = ENetMultiplayerPeer.new()
	var error = peer.create_server(port, MAX_CLIENTS)
	var retry_count = 0
	while error != OK and retry_count < 10:
		port = randi_range(20000, 60000)
		error = peer.create_server(port, MAX_CLIENTS)
		retry_count += 1
	if error != OK:
		print("Failed to create server: ", error)
		return

	multiplayer.multiplayer_peer = peer
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)

	var local_ip = IP.get_local_addresses()
	print("Server started on port %d. Local IPs: %s" % [port, local_ip])

	# Start broadcasting this server for discovery
	ServerDiscovery.start_broadcasting(server_name, port, MAX_CLIENTS)

	# Switch to world scene
	get_tree().change_scene_to_file("res://Scenes/world.tscn")

func join_server(ip_address: String, port: int = DEFAULT_PORT) -> void:
	peer = ENetMultiplayerPeer.new()
	var error = peer.create_client(ip_address, port)
	if error != OK:
		print("Failed to connect to server: ", error)
		return

	multiplayer.multiplayer_peer = peer
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected) # <— add this

	print("Attempting to connect to ", ip_address, ":", port)


func start_client() -> void:
	# This now opens the server browser instead of connecting directly
	get_tree().change_scene_to_file("res://Scenes/server_browser.tscn")

func _on_peer_connected(id: int):
	print("Peer connected:", id)
	var player_count = multiplayer.get_peers().size() + 1
	ServerDiscovery.update_player_count(player_count)
	
	if player_count > MAX_CLIENTS:
		print("Server full! Disconnecting peer:", id)
		rpc_id(id, "_notify_server_full")
		await get_tree().create_timer(0.1).timeout  # short delay to send RPC before drop
		peer.disconnect_peer(id)

		
@rpc("any_peer")
func _notify_server_full():
	print("Server is full! Returning to server browser.")
	get_tree().change_scene_to_file("res://Scenes/server_browser.tscn")


func _on_peer_disconnected(id: int):
	print("Peer disconnected: ", id)
	# Update player count for server discovery
	var player_count = multiplayer.get_peers().size() + 1  # +1 for server
	ServerDiscovery.update_player_count(player_count)
	
func _on_server_disconnected():
	print("Disconnected from server (possibly full). Returning to browser...")
	get_tree().change_scene_to_file("res://Scenes/server_browser.tscn")

func _on_connected_to_server():
	print("Successfully connected to server!")
	get_tree().change_scene_to_file("res://Scenes/world.tscn")

func _on_connection_failed():
	print("Failed to connect to server")
	# Return to server browser on failure
	get_tree().change_scene_to_file("res://Scenes/server_browser.tscn")

func _exit_tree():
	# Clean up when closing
	if peer:
		peer.close()
	ServerDiscovery.stop_broadcasting()
