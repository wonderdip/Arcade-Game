extends Node

const DEFAULT_PORT: int = 41677
var MAX_CLIENTS: int = 2

var peer: ENetMultiplayerPeer
var is_local: bool = false
var is_solo: bool = false
var server_name: String = ""

func start_server(server_name_param: String = "", port: int = DEFAULT_PORT) -> void:
	if server_name_param != "":
		server_name = server_name_param

	peer = ENetMultiplayerPeer.new()
	var error = peer.create_server(port, MAX_CLIENTS)

	var retry_count = 0
	while error != OK and retry_count < 10:
		port = randi_range(20000, 60000)
		error = peer.create_server(port, MAX_CLIENTS)
		retry_count += 1

	if error != OK:
		push_error("❌ Failed to create server: %s" % error)
		return

	multiplayer.multiplayer_peer = peer
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)

	var local_ips = IP.get_local_addresses()
	print("✅ Server started on port %d" % port)
	print("🌐 Local IPs: ", local_ips)

	# Start broadcasting AFTER server is created
	ServerDiscovery.start_broadcasting(server_name, port, MAX_CLIENTS)

	get_tree().change_scene_to_file("res://Scenes/world.tscn")

# -------------------------------------------------------------------

func join_server(ip_address: String, port: int = DEFAULT_PORT) -> void:
	print("🔌 Attempting to connect to server at %s:%d" % [ip_address, port])

	peer = ENetMultiplayerPeer.new()
	var error = peer.create_client(ip_address, port)
	if error != OK:
		push_error("❌ Failed to connect: %s" % error)
		return

	multiplayer.multiplayer_peer = peer
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)

# -------------------------------------------------------------------

func start_client() -> void:
	get_tree().change_scene_to_file("res://Scenes/server_browser.tscn")

# -------------------------------------------------------------------

func _on_peer_connected(id: int) -> void:
	print("🟢 Peer connected:", id)
	var player_count = multiplayer.get_peers().size() + 1  # +1 = server itself
	ServerDiscovery.update_player_count(player_count)

	if player_count > MAX_CLIENTS:
		print("⚠️ Server full! Disconnecting peer:", id)
		rpc_id(id, "_notify_server_full")
		await get_tree().create_timer(0.1).timeout
		peer.disconnect_peer(id)

@rpc("any_peer")
func _notify_server_full():
	print("🚫 Server is full! Returning to browser.")
	get_tree().change_scene_to_file("res://Scenes/server_browser.tscn")

# -------------------------------------------------------------------

func _on_peer_disconnected(id: int) -> void:
	print("🔴 Peer disconnected:", id)
	var player_count = multiplayer.get_peers().size() + 1
	ServerDiscovery.update_player_count(player_count)

func _on_server_disconnected() -> void:
	print("⚠️ Disconnected from server. Returning to browser.")
	get_tree().change_scene_to_file("res://Scenes/server_browser.tscn")

func _on_connected_to_server() -> void:
	print("✅ Connected to server successfully!")
	get_tree().change_scene_to_file("res://Scenes/world.tscn")

func _on_connection_failed() -> void:
	print("❌ Connection failed. Returning to browser.")
	get_tree().change_scene_to_file("res://Scenes/server_browser.tscn")

# -------------------------------------------------------------------

func _exit_tree() -> void:
	if peer:
		peer.close()
	ServerDiscovery.stop_broadcasting()
