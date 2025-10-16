extends Node

signal server_discovered(server_info)

const BROADCAST_PORT: int = 41678  # Port for server to listen on
const DISCOVERY_INTERVAL: float = 2.0

var udp_server: PacketPeerUDP
var udp_client: PacketPeerUDP
var discovery_timer: Timer
var is_broadcasting: bool = false
var is_discovering: bool = false

var current_server_info: Dictionary = {}

func _ready():
	discovery_timer = Timer.new()
	discovery_timer.wait_time = DISCOVERY_INTERVAL
	discovery_timer.timeout.connect(_on_discovery_timer_timeout)
	add_child(discovery_timer)


# -----------------------------
# SERVER SIDE
# -----------------------------
func start_broadcasting(server_name: String, game_port: int, max_players: int = 2):
	if is_broadcasting:
		return
	
	udp_server = PacketPeerUDP.new()
	# Server listens on BROADCAST_PORT
	var err = udp_server.bind(BROADCAST_PORT, "*")
	if err != OK:
		push_error("Failed to bind UDP server on port %d: %s" % [BROADCAST_PORT, err])
		return
	
	# CRITICAL: Enable broadcast receiving
	udp_server.set_broadcast_enabled(true)
	
	current_server_info = {
		"type": "server_info",
		"name": server_name,
		"port": game_port,
		"max_players": max_players,
		"players": 1,
		"version": "1.0"
	}
	
	is_broadcasting = true
	print("UDP broadcasting enabled on port %d (game port: %d)" % [BROADCAST_PORT, game_port])

# -----------------------------
# CLIENT SIDE
# -----------------------------
func start_discovery_client():
	if is_discovering:
		return
	
	udp_client = PacketPeerUDP.new()
	# Client uses ephemeral port (0 = auto-assign)
	var err = udp_client.bind(0, "*")
	if err != OK:
		push_error("Failed to bind UDP client: %s" % [err])
		return
	
	udp_client.set_broadcast_enabled(true)
	is_discovering = true
	
	# Wait a frame to ensure socket is ready
	await get_tree().process_frame
	
	# Send initial discovery request
	send_discovery_request()
	
	# Start periodic discovery
	discovery_timer.start()
	print("Started discovery client")


func send_discovery_request():
	if not is_discovering or udp_client == null:
		return
	
	var message = {"type": "discovery_request"}
	var data = JSON.stringify(message).to_utf8_buffer()

	# Send to broadcast addresses
	for bcast in _get_broadcast_addresses():
		udp_client.set_dest_address(bcast, BROADCAST_PORT)
		var result = udp_client.put_packet(data)
		if result == OK:
			print("Sent discovery request to %s:%d" % [bcast, BROADCAST_PORT])
		else:
			print("Failed to send to %s: %s" % [bcast, result])


# -----------------------------
# STOP FUNCTIONS
# -----------------------------
func stop_broadcasting():
	if udp_server:
		udp_server.close()
		udp_server = null
	is_broadcasting = false
	print("Stopped broadcasting")

func stop_discovery_client():
	if udp_client:
		udp_client.close()
		udp_client = null
	discovery_timer.stop()
	is_discovering = false
	print("Stopped discovery client")

func _process(_delta):
	# SERVER: respond to discovery requests
	if is_broadcasting and udp_server and udp_server.get_available_packet_count() > 0:
		while udp_server.get_available_packet_count() > 0:
			var packet = udp_server.get_packet()
			var sender_ip = udp_server.get_packet_ip()
			var sender_port = udp_server.get_packet_port()
			var message_str = packet.get_string_from_utf8()
			var message = JSON.parse_string(message_str)
			
			if message and message.get("type") == "discovery_request":
				print("Discovery request from: %s:%d" % [sender_ip, sender_port])
				_send_server_info(sender_ip, sender_port)

	# CLIENT: receive server info responses
	if is_discovering and udp_client and udp_client.get_available_packet_count() > 0:
		while udp_client.get_available_packet_count() > 0:
			var packet = udp_client.get_packet()
			var sender_ip = udp_client.get_packet_ip()
			var message_str = packet.get_string_from_utf8()
			var server_info = JSON.parse_string(message_str)
			
			if server_info and server_info.get("type") == "server_info":
				server_info.ip = sender_ip
				print("Found server: '%s' at %s:%d (Players: %d/%d)" % [
					server_info.get("name", "Unnamed"),
					sender_ip,
					server_info.get("port", 0),
					server_info.get("players", 0),
					server_info.get("max_players", 0)
				])
				emit_signal("server_discovered", server_info)


# -----------------------------
# HELPERS
# -----------------------------
func _send_server_info(target_ip: String, target_port: int):
	if not udp_server:
		return
	
	var response = current_server_info.duplicate()
	response["type"] = "server_info"

	# Send response directly back to requester
	udp_server.set_dest_address(target_ip, target_port)
	var result = udp_server.put_packet(JSON.stringify(response).to_utf8_buffer())
	
	if result == OK:
		print("Sent server info to %s:%d" % [target_ip, target_port])
	else:
		print("Failed to send server info: %s" % result)


func _on_discovery_timer_timeout():
	if is_discovering:
		send_discovery_request()


# Get valid local IP (not 127.0.0.1)
func _get_local_ip() -> String:
	for ip in IP.get_local_addresses():
		if not ip.begins_with("127.") and ip.find(":") == -1:  # ignore IPv6
			return ip
	return "0.0.0.0"


# Get broadcast addresses for local network
func _get_broadcast_addresses() -> Array:
	var result = []
	
	# Add global broadcast first
	result.append("255.255.255.255")
	
	# Add subnet-specific broadcasts based on local IPs
	for addr in IP.get_local_addresses():
		# Skip loopback and IPv6
		if addr.begins_with("127.") or addr.find(":") != -1:
			continue
			
		var parts = addr.split(".")
		if parts.size() != 4:
			continue
		
		# For any valid IPv4 address, create its broadcast address
		# Standard /24 subnet (most common home networks)
		var broadcast_24 = "%s.%s.%s.255" % [parts[0], parts[1], parts[2]]
		if broadcast_24 not in result:
			result.append(broadcast_24)
		
		# Also try /16 subnet for larger networks
		if addr.begins_with("10.") or addr.begins_with("172."):
			var broadcast_16 = "%s.%s.255.255" % [parts[0], parts[1]]
			if broadcast_16 not in result:
				result.append(broadcast_16)
	
	print("Broadcasting to addresses: ", result)
	return result

# Update player count dynamically
# called by networkhandler
func update_player_count(count: int):
	if current_server_info.has("players"):
		current_server_info.players = count
		print("Player count is: %d" % count)

func _exit_tree():
	stop_broadcasting()
	stop_discovery_client()
