extends Node

signal server_discovered(server_info)

const BROADCAST_PORT: int = 41678
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
	var err = udp_server.bind(BROADCAST_PORT, "*")
	if err != OK:
		push_error("Failed to bind UDP server: %s" % [err])
		return
	
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
	print("🔊 Started broadcasting server:", server_name, "on port", game_port)


# -----------------------------
# CLIENT SIDE
# -----------------------------
func start_discovery_client():
	if is_discovering:
		return
	
	udp_client = PacketPeerUDP.new()
	var err = udp_client.bind(BROADCAST_PORT + 1, "*")
	if err != OK:
		push_error("Failed to bind UDP client: %s" % [err])
		return
	
	udp_client.set_broadcast_enabled(true)
	is_discovering = true
	discovery_timer.start()
	print("📡 Started discovery client on port", BROADCAST_PORT + 1)


func send_discovery_request():
	if not is_discovering or udp_client == null:
		return
	
	var message = {"type": "discovery_request"}
	var data = JSON.stringify(message).to_utf8_buffer()

	# Send to both global and subnet broadcast
	for bcast in _get_broadcast_addresses():
		udp_client.set_dest_address(bcast, BROADCAST_PORT)
		udp_client.put_packet(data)
		print("➡️ Sent discovery request to", bcast, ":", BROADCAST_PORT)


# -----------------------------
# STOP FUNCTIONS
# -----------------------------
func stop_broadcasting():
	if udp_server:
		udp_server.close()
		udp_server = null
	is_broadcasting = false
	print("🛑 Stopped broadcasting")


func stop_discovery_client():
	if udp_client:
		udp_client.close()
		udp_client = null
	discovery_timer.stop()
	is_discovering = false
	print("🛑 Stopped discovery client")


# -----------------------------
# MAIN LOOP
# -----------------------------
func _process(_delta):
	# SERVER: respond to discovery requests
	if is_broadcasting and udp_server:
		while udp_server.get_available_packet_count() > 0:
			var packet = udp_server.get_packet()
			var message_str = packet.get_string_from_utf8()
			var message = JSON.parse_string(message_str)
			
			if message and message.get("type") == "discovery_request":
				var sender_ip = udp_server.get_packet_ip()
				print("📨 Discovery request received from:", sender_ip)
				_send_server_info(sender_ip)

	# CLIENT: receive server info responses
	if is_discovering and udp_client:
		while udp_client.get_available_packet_count() > 0:
			var packet = udp_client.get_packet()
			var sender_ip = udp_client.get_packet_ip()
			var message_str = packet.get_string_from_utf8()
			var server_info = JSON.parse_string(message_str)
			
			if server_info and server_info.get("type") == "server_info":
				server_info.ip = sender_ip
				print("✅ Found server:", server_info.name, "at", sender_ip)
				emit_signal("server_discovered", server_info)


# -----------------------------
# HELPERS
# -----------------------------
func _send_server_info(target_ip: String):
	if not udp_server:
		return
	
	var response = current_server_info.duplicate()
	response["type"] = "server_info"
	response["ip"] = _get_local_ip()

	var temp_udp = PacketPeerUDP.new()
	temp_udp.set_broadcast_enabled(true)
	temp_udp.set_dest_address(target_ip, BROADCAST_PORT + 1)
	temp_udp.put_packet(JSON.stringify(response).to_utf8_buffer())
	await get_tree().process_frame  # give time to send
	temp_udp.close()
	print("📤 Sent server info to", target_ip)


func _on_discovery_timer_timeout():
	if is_discovering:
		send_discovery_request()


# Get valid local IP (not 127.0.0.1)
func _get_local_ip() -> String:
	for ip in IP.get_local_addresses():
		if not ip.begins_with("127.") and ip.find(":") == -1:  # ignore IPv6
			return ip
	return "0.0.0.0"


# Get both 255.255.255.255 and subnet broadcasts
func _get_broadcast_addresses() -> Array:
	var result = ["255.255.255.255"]
	for addr in IP.get_local_addresses():
		if addr.begins_with("192.168.") or addr.begins_with("10.") or addr.begins_with("172."):
			var parts = Array(addr.split("."))
			if parts.size() == 4:
				parts[3] = "255"
				result.append(".".join(parts))
	return result

# Update player count dynamically
func update_player_count(count: int):
	if current_server_info.has("players"):
		current_server_info.players = count


func _exit_tree():
	stop_broadcasting()
	stop_discovery_client()
