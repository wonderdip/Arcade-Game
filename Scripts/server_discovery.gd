extends Node

signal server_discovered(server_info)

const BROADCAST_PORT: int = 41678
const DISCOVERY_INTERVAL: float = 2.0  # Slower to reduce spam

var udp_server: PacketPeerUDP
var udp_client: PacketPeerUDP
var discovery_timer: Timer
var is_broadcasting: bool = false
var is_discovering: bool = false

var current_server_info: Dictionary = {}
var discovered_servers_cache: Dictionary = {}  # Cache by server_id to prevent duplicates

func _ready():
	discovery_timer = Timer.new()
	discovery_timer.wait_time = DISCOVERY_INTERVAL
	discovery_timer.timeout.connect(_on_discovery_timer_timeout)
	add_child(discovery_timer)
	
	set_process(true)

# -----------------------------
# SERVER SIDE
# -----------------------------
func start_broadcasting(server_name: String, game_port: int, max_players: int = 2):
	print("[Discovery] Starting broadcast...")
	
	if is_broadcasting:
		stop_broadcasting()
	
	udp_server = PacketPeerUDP.new()
	
	var err = udp_server.bind(BROADCAST_PORT)
	if err != OK:
		push_error("[Discovery] Failed to bind server on port %d: %s" % [BROADCAST_PORT, err])
		udp_server = null
		return
	
	udp_server.set_broadcast_enabled(true)
	
	# Create unique server ID based on name and port
	var server_id = "%s:%d" % [server_name, game_port]
	
	current_server_info = {
		"type": "server_info",
		"server_id": server_id,  # NEW: Unique identifier
		"name": server_name,
		"port": game_port,
		"max_players": max_players,
		"players": 1,
		"version": "1.0"
	}
	
	is_broadcasting = true
	print("[Discovery] Broadcasting as '%s' on port %d (game port: %d)" % [server_name, BROADCAST_PORT, game_port])

# -----------------------------
# CLIENT SIDE
# -----------------------------
func start_discovery_client():
	print("[Discovery] Starting client discovery...")
	
	if is_discovering:
		stop_discovery_client()
	
	# Clear cache when starting new discovery
	discovered_servers_cache.clear()
	
	udp_client = PacketPeerUDP.new()
	
	var err = udp_client.bind(0)
	if err != OK:
		push_error("[Discovery] Failed to bind client: %s" % err)
		udp_client = null
		return
	
	udp_client.set_broadcast_enabled(true)
	is_discovering = true
	
	print("[Discovery] Client bound successfully")
	
	await get_tree().process_frame
	
	send_discovery_request()
	
	if discovery_timer:
		discovery_timer.start()

func send_discovery_request():
	if not is_discovering or udp_client == null:
		return
	
	var message = {"type": "discovery_request", "timestamp": Time.get_ticks_msec()}
	var data = JSON.stringify(message).to_utf8_buffer()
	
	# Only broadcast to local subnet
	var local_ip = _get_local_ip()
	var broadcast_addr = _get_subnet_broadcast(local_ip)
	
	udp_client.set_dest_address(broadcast_addr, BROADCAST_PORT)
	var result = udp_client.put_packet(data)
	
	if result == OK:
		print("[Discovery] Sent discovery to %s:%d" % [broadcast_addr, BROADCAST_PORT])

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
	discovered_servers_cache.clear()
	print("[Discovery] Stopped discovery client")

func _process(_delta):
	# SERVER: Listen for and respond to discovery requests
	if is_broadcasting and udp_server:
		while udp_server.get_available_packet_count() > 0:
			var packet = udp_server.get_packet()
			var sender_ip = udp_server.get_packet_ip()
			var sender_port = udp_server.get_packet_port()
			
			if packet.size() == 0:
				continue
			
			var message_str = packet.get_string_from_utf8()
			var message = JSON.parse_string(message_str)
			
			if message and message.get("type") == "discovery_request":
				_send_server_info(sender_ip, sender_port)

	# CLIENT: Listen for server responses
	if is_discovering and udp_client:
		while udp_client.get_available_packet_count() > 0:
			var packet = udp_client.get_packet()
			var sender_ip = udp_client.get_packet_ip()
			
			if packet.size() == 0:
				continue
			
			var message_str = packet.get_string_from_utf8()
			var server_info = JSON.parse_string(message_str)
			
			if server_info and server_info.get("type") == "server_info":
				# Check if we've already discovered this server
				var server_id = server_info.get("server_id", "")
				
				if server_id != "" and not discovered_servers_cache.has(server_id):
					# New server discovered
					discovered_servers_cache[server_id] = true
					server_info["ip"] = sender_ip
					
					print("[Discovery] ✓ New server: '%s' at %s:%d" % [
						server_info.get("name", "Unnamed"),
						sender_ip,
						server_info.get("port", 0)
					])
					
					emit_signal("server_discovered", server_info)

# -----------------------------
# HELPERS
# -----------------------------
func _send_server_info(target_ip: String, target_port: int):
	if not udp_server:
		return
	
	var response = current_server_info.duplicate()
	var data = JSON.stringify(response).to_utf8_buffer()

	udp_server.set_dest_address(target_ip, target_port)
	var result = udp_server.put_packet(data)
	
	if result == OK:
		print("[Discovery] ✓ Sent info to %s:%d" % [target_ip, target_port])

func _on_discovery_timer_timeout():
	if is_discovering:
		send_discovery_request()

func _get_local_ip() -> String:
	for ip in IP.get_local_addresses():
		if not ip.begins_with("127.") and ip.find(":") == -1:
			if ip.begins_with("192.168.") or ip.begins_with("10."):
				return ip
	return "192.168.1.1"  # Fallback

func _get_subnet_broadcast(ip: String) -> String:
	var parts = ip.split(".")
	if parts.size() != 4:
		return "255.255.255.255"
	
	# Assume /24 subnet for local networks
	return "%s.%s.%s.255" % [parts[0], parts[1], parts[2]]

func update_player_count(count: int):
	if current_server_info.has("players"):
		current_server_info.players = count

func _exit_tree():
	stop_broadcasting()
	stop_discovery_client()
