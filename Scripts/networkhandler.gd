extends Node

const DEFAULT_PORT: int = 41677
const MAX_RETRY_ATTEMPTS: int = 10
const PORT_RANGE_MIN: int = 20000
const PORT_RANGE_MAX: int = 60000

var MAX_CLIENTS: int = 2

var peer: ENetMultiplayerPeer
var is_local: bool = false
var is_solo: bool = false
var server_name: String = ""

# Connection state tracking
var is_server: bool = false
var is_client: bool = false
var connection_attempts: int = 0

func _ready() -> void:
	# Clear any existing connections on startup
	reset_network()

# ========================================
# SERVER FUNCTIONS
# ========================================

# Replace the start_server and join_server functions in Scripts/networkhandler.gd

func start_server(server_name_param: String = "", port: int = DEFAULT_PORT) -> void:
	if server_name_param != "":
		server_name = server_name_param
	
	reset_network()
	
	peer = ENetMultiplayerPeer.new()
	var error = peer.create_server(port, MAX_CLIENTS)
	
	# Retry with random ports if default fails
	var retry_count = 0
	while error != OK and retry_count < MAX_RETRY_ATTEMPTS:
		port = randi_range(PORT_RANGE_MIN, PORT_RANGE_MAX)
		error = peer.create_server(port, MAX_CLIENTS)
		retry_count += 1
	
	if error != OK:
		push_error("Failed to create server after %d attempts: %s" % [MAX_RETRY_ATTEMPTS, error])
		_show_error_and_return("Failed to start server")
		return
	
	# CRITICAL OPTIMIZATION: Enable compression for lower bandwidth
	peer.get_host().compress(ENetConnection.COMPRESS_RANGE_CODER)
	
	multiplayer.multiplayer_peer = peer
	is_server = true
	is_client = false
	
	# Connect server signals
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	
	print("Server started on port %d with compression enabled" % port)
	
	# Start broadcasting server info
	ServerDiscovery.start_broadcasting(server_name, port, MAX_CLIENTS)
	
	# Load game scene
	get_tree().change_scene_to_file("res://Scenes/world.tscn")

func join_server(ip_address: String, port: int = DEFAULT_PORT) -> void:
	print("Attempting to connect to %s:%d" % [ip_address, port])
	
	reset_network()
	
	peer = ENetMultiplayerPeer.new()
	var error = peer.create_client(ip_address, port)
	
	if error != OK:
		push_error("Failed to create client: %s" % error)
		_show_error_and_return("Failed to connect")
		return
	
	# CRITICAL OPTIMIZATION: Enable compression for lower bandwidth
	peer.get_host().compress(ENetConnection.COMPRESS_RANGE_CODER)
	
	multiplayer.multiplayer_peer = peer
	is_client = true
	is_server = false
	connection_attempts = 0
	
	# Connect client signals
	if not multiplayer.connected_to_server.is_connected(_on_connected_to_server):
		multiplayer.connected_to_server.connect(_on_connected_to_server)
	if not multiplayer.connection_failed.is_connected(_on_connection_failed):
		multiplayer.connection_failed.connect(_on_connection_failed)
	if not multiplayer.server_disconnected.is_connected(_on_server_disconnected):
		multiplayer.server_disconnected.connect(_on_server_disconnected)
	
	print("Client created with compression enabled")
	
func _on_peer_connected(id: int) -> void:
	if not is_server:
		return
	
	print("Peer connected: %d" % id)
	var player_count = multiplayer.get_peers().size() + 1
	ServerDiscovery.update_player_count(player_count)
	
	# Check if server is full
	if player_count > MAX_CLIENTS:
		print("Server full, rejecting peer %d" % id)
		_kick_peer.rpc_id(id, "Server is full")
		await get_tree().create_timer(0.1).timeout
		peer.disconnect_peer(id)

func _on_peer_disconnected(id: int) -> void:
	if not is_server:
		return
	
	print("Peer disconnected: %d" % id)
	var player_count = multiplayer.get_peers().size() + 1
	ServerDiscovery.update_player_count(player_count)

@rpc("authority", "call_remote", "reliable")
func _kick_peer(reason: String) -> void:
	print("Kicked from server: %s" % reason)
	_show_error_and_return(reason)

# ========================================
# CLIENT FUNCTIONS
# ========================================

func start_client() -> void:
	"""Open the server browser"""
	reset_network()
	get_tree().change_scene_to_file("res://Scenes/Menus/server_browser.tscn")

func _on_connected_to_server() -> void:
	print("Successfully connected to server")
	connection_attempts = 0
	get_tree().change_scene_to_file("res://Scenes/world.tscn")

func _on_connection_failed() -> void:
	connection_attempts += 1
	print("Connection failed (attempt %d/%d)" % [connection_attempts, MAX_RETRY_ATTEMPTS])
	
	if connection_attempts >= MAX_RETRY_ATTEMPTS:
		_show_error_and_return("Connection failed after %d attempts" % MAX_RETRY_ATTEMPTS)
	else:
		_show_error_and_return("Connection failed")

func _on_server_disconnected() -> void:
	print("Disconnected from server")
	reset_network()
	get_tree().change_scene_to_file("res://Scenes/Menus/server_browser.tscn")

# ========================================
# CLEANUP FUNCTIONS
# ========================================

func reset_network() -> void:
	"""Clean up all network connections and state"""
	if peer:
		peer.close()
		peer = null
	
	# Disconnect all signals
	if multiplayer.peer_connected.is_connected(_on_peer_connected):
		multiplayer.peer_connected.disconnect(_on_peer_connected)
	if multiplayer.peer_disconnected.is_connected(_on_peer_disconnected):
		multiplayer.peer_disconnected.disconnect(_on_peer_disconnected)
	if multiplayer.connected_to_server.is_connected(_on_connected_to_server):
		multiplayer.connected_to_server.disconnect(_on_connected_to_server)
	if multiplayer.connection_failed.is_connected(_on_connection_failed):
		multiplayer.connection_failed.disconnect(_on_connection_failed)
	if multiplayer.server_disconnected.is_connected(_on_server_disconnected):
		multiplayer.server_disconnected.disconnect(_on_server_disconnected)
	
	multiplayer.multiplayer_peer = null
	
	ServerDiscovery.stop_discovery_client()
	ServerDiscovery.stop_broadcasting()
	
	is_server = false
	is_client = false
	connection_attempts = 0
	
	print("Network reset complete")

func _show_error_and_return(message: String) -> void:
	"""Show error and return to server browser"""
	reset_network()
	get_tree().change_scene_to_file("res://Scenes/Menus/server_browser.tscn")

func _exit_tree() -> void:
	reset_network()
