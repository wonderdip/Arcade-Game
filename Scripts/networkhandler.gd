extends Node

const IP_ADDRESS = "localhost"
const PORT: int = 41677
const MAX_CLIENTS: int = 2

var peer: ENetMultiplayerPeer
var is_local: bool = false

func start_server() -> void:
	peer = ENetMultiplayerPeer.new()
	var error = peer.create_server(PORT, MAX_CLIENTS)
	if error != OK:
		print("Failed to create server: ", error)
		return
	
	multiplayer.multiplayer_peer = peer
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	
	var local_ip = IP.get_local_addresses()
	print("Server started on port %d. Local IPs: %s" % [PORT, local_ip])
	
	# Switch to world scene
	get_tree().change_scene_to_file("res://Scenes/world.tscn")


func start_client() -> void:
	peer = ENetMultiplayerPeer.new()
	var error = peer.create_client(IP_ADDRESS, PORT)
	if error != OK:
		print("Failed to connect to server: ", error)
		return
	
	multiplayer.multiplayer_peer = peer
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	
	print("Attempting to connect to ", IP_ADDRESS, ":", PORT)


func _on_peer_connected(id: int):
	print("Peer connected: ", id)

func _on_peer_disconnected(id: int):
	print("Peer disconnected: ", id)

func _on_connected_to_server():
	print("Successfully connected to server!")
	get_tree().change_scene_to_file("res://Scenes/world.tscn")

func _on_connection_failed():
	print("Failed to connect to server")
