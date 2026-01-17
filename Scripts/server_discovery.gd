extends Node

signal server_discovered(server_info)

const BROADCAST_PORT: int = 41678
const DISCOVERY_INTERVAL: float = 1.0  # Reduced for faster discovery

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
	
	# Set process to always run
	set_process(true)

# -----------------------------
# SERVER SIDE
# -----------------------------
func start_broadcasting(server_name: String, game_port: int, max_players: int = 2):
	print("[Discovery] Starting broadcast...")
	
	if is_broadcasting:
		stop_broadcasting()
	
	udp_server = PacketPeerUDP.new()
	
	# CRITICAL: Bind to broadcast port with proper settings
	var err = udp_server.bind(BROADCAST_PORT)
	if err != OK:
		push_error("[Discovery] Failed to bind server on port %d: %s" % [BROADCAST_PORT, err])
		udp_server = null
		return
	
	# Enable broadcast AFTER binding
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
	print("[Discovery] Broadcasting as '%s' on port %d (game port: %d)" % [server_name, BROADCAST_PORT, game_port])
	print("[Discovery] Server info: ", current_server_info)

# -----------------------------
# CLIENT SIDE
# -----------------------------
func start_discovery_client():
	print("[Discovery] Starting client discovery...")
	
	if is_discovering:
		stop_discovery_client()
	
	udp_client = PacketPeerUDP.new()
	
	# Bind to any available port
	var err = udp_client.bind(0)
	if err != OK:
		push_error("[Discovery] Failed to bind client: %s" % err)
		udp_client = null
		return
	
	# Enable broadcast
	udp_client.set_broadcast_enabled(true)
	is_discovering = true
	
	print("[Discovery] Client bound successfully, sending initial request...")
	
	# Wait a frame for socket to be ready
	await get_tree().process_frame
	
	# Send initial discovery
	send_discovery_request()
	
	# Start timer for periodic discovery
	if discovery_timer:
		discovery_timer.start()

func send_discovery_request():
	if not is_discovering or udp_client == null:
		print("[Discovery] Cannot send request - client not ready")
		return
	
	var message = {"type": "discovery_request", "timestamp": Time.get_ticks_msec()}
	var data = JSON.stringify(message).to_utf8_buffer()
	
	print("[Discovery] Sending discovery request...")
	
	var sent_count = 0
	for bcast in _get_broadcast_addresses():
		udp_client.set_dest_address(bcast, BROADCAST_PORT)
		var result = udp_client.put_packet(data)
		if result == OK:
			sent_count += 1
			print("[Discovery] ✓ Sent to %s:%d" % [bcast, BROADCAST_PORT])
		else:
			print("[Discovery] ✗ Failed to send to %s: %s" % [bcast, result])
	
	print("[Discovery] Sent %d broadcast packets" % sent_count)

# -----------------------------
# STOP FUNCTIONS
# -----------------------------
func stop_broadcasting():
	if udp_server:
		udp_server.close()
		udp_server = null
	is_broadcasting = false
	print("[Discovery] Stopped broadcasting")

func stop_discovery_client():
	if udp_client:
		udp_client.close()
		udp_client = null
	
	if discovery_timer and discovery_timer.is_inside_tree():
		discovery_timer.stop()
	
	is_discovering = false
	print("[Discovery] Stopped discovery client")

func _process(_delta):
	# SERVER: Listen for and respond to discovery requests
	if is_broadcasting and udp_server:
		var packet_count = udp_server.get_available_packet_count()
		if packet_count > 0:
			print("[Discovery] Server received %d packet(s)" % packet_count)
		
		while udp_server.get_available_packet_count() > 0:
			var packet = udp_server.get_packet()
			var sender_ip = udp_server.get_packet_ip()
			var sender_port = udp_server.get_packet_port()
			
			if packet.size() == 0:
				print("[Discovery] Received empty packet")
				continue
			
			var message_str = packet.get_string_from_utf8()
			print("[Discovery] Received from %s:%d - %s" % [sender_ip, sender_port, message_str])
			
			var message = JSON.parse_string(message_str)
			
			if message and message.get("type") == "discovery_request":
				print("[Discovery] Valid discovery request from: %s:%d" % [sender_ip, sender_port])
				_send_server_info(sender_ip, sender_port)
			else:
				print("[Discovery] Invalid message format or type")

	# CLIENT: Listen for server responses
	if is_discovering and udp_client:
		var packet_count = udp_client.get_available_packet_count()
		if packet_count > 0:
			print("[Discovery] Client received %d packet(s)" % packet_count)
		
		while udp_client.get_available_packet_count() > 0:
			var packet = udp_client.get_packet()
			var sender_ip = udp_client.get_packet_ip()
			
			if packet.size() == 0:
				print("[Discovery] Received empty packet")
				continue
			
			var message_str = packet.get_string_from_utf8()
			print("[Discovery] Received from %s - %s" % [sender_ip, message_str])
			
			var server_info = JSON.parse_string(message_str)
			
			if server_info and server_info.get("type") == "server_info":
				server_info["ip"] = sender_ip
				print("[Discovery] ✓ Found server: '%s' at %s:%d (Players: %d/%d)" % [
					server_info.get("name", "Unnamed"),
					sender_ip,
					server_info.get("port", 0),
					server_info.get("players", 0),
					server_info.get("max_players", 0)
				])
				emit_signal("server_discovered", server_info)
			else:
				print("[Discovery] Invalid server info format")

# -----------------------------
# HELPERS
# -----------------------------
func _send_server_info(target_ip: String, target_port: int):
	if not udp_server:
		print("[Discovery] Cannot send info - server not ready")
		return
	
	var response = current_server_info.duplicate()
	response["type"] = "server_info"
	
	var data = JSON.stringify(response).to_utf8_buffer()
	print("[Discovery] Sending server info to %s:%d - %s" % [target_ip, target_port, JSON.stringify(response)])

	udp_server.set_dest_address(target_ip, target_port)
	var result = udp_server.put_packet(data)
	
	if result == OK:
		print("[Discovery] ✓ Sent server info to %s:%d" % [target_ip, target_port])
	else:
		print("[Discovery] ✗ Failed to send server info: %s" % result)

func _on_discovery_timer_timeout():
	if is_discovering:
		print("[Discovery] Timer tick - sending periodic request")
		send_discovery_request()

func _get_local_ip() -> String:
	for ip in IP.get_local_addresses():
		if not ip.begins_with("127.") and ip.find(":") == -1:
			return ip
	return "0.0.0.0"

func _get_broadcast_addresses() -> Array:
	var result = []
	
	# Always add global broadcast
	result.append("255.255.255.255")
	
	# Add localhost for testing
	result.append("127.0.0.1")
	
	# Add subnet-specific broadcasts
	for addr in IP.get_local_addresses():
		# Skip loopback and IPv6
		if addr.begins_with("127.") or addr.find(":") != -1:
			continue
			
		var parts = addr.split(".")
		if parts.size() != 4:
			continue
		
		# /24 subnet (most common)
		var broadcast_24 = "%s.%s.%s.255" % [parts[0], parts[1], parts[2]]
		if broadcast_24 not in result:
			result.append(broadcast_24)
		
		# /16 subnet for larger networks
		if addr.begins_with("10.") or addr.begins_with("172."):
			var broadcast_16 = "%s.%s.255.255" % [parts[0], parts[1]]
			if broadcast_16 not in result:
				result.append(broadcast_16)
	
	print("[Discovery] Broadcast addresses: ", result)
	return result

func update_player_count(count: int):
	if current_server_info.has("players"):
		current_server_info.players = count
		print("[Discovery] Player count updated to: %d" % count)

func _exit_tree():
	stop_broadcasting()
	stop_discovery_client()
