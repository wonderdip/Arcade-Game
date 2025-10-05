extends Node

signal server_discovered(server_info)

const BROADCAST_PORT: int = 41678  # Different from game port to avoid conflicts
const BROADCAST_ADDRESS: String = "255.255.255.255"
const DISCOVERY_INTERVAL: float = 5.0

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

# Server-side: Start broadcasting server availability
func start_broadcasting(server_name: String, game_port: int, max_players: int = 2):
	if is_broadcasting:
		return
	
	udp_server = PacketPeerUDP.new()
	udp_server.bind(BROADCAST_PORT)
	
	current_server_info = {
		"name": server_name,
		"port": game_port,
		"max_players": max_players,
		"players": 1,  # Server counts as 1 player
		"version": "1.0"  # For compatibility checking
	}
	
	is_broadcasting = true
	print("Started broadcasting server: ", server_name)

# Client-side: Start listening for server broadcasts
func start_discovery_client():
	if is_discovering:
		return
		
	udp_client = PacketPeerUDP.new()
	udp_client.bind(BROADCAST_PORT + 1)  # Use different port for client
	
	is_discovering = true
	discovery_timer.start()
	print("Started discovery client")

# Send a discovery request (client)
func send_discovery_request():
	if not is_discovering:
		return
		
	var message = {"type": "discovery_request"}
	var json_message = JSON.stringify(message)
	udp_client.set_dest_address(BROADCAST_ADDRESS, BROADCAST_PORT)
	udp_client.put_packet(json_message.to_utf8_buffer())

# Stop broadcasting (server)
func stop_broadcasting():
	is_broadcasting = false
	if udp_server:
		udp_server.close()
		udp_server = null
	print("Stopped broadcasting")

# Stop discovery (client)
func stop_discovery_client():
	is_discovering = false
	discovery_timer.stop()
	if udp_client:
		udp_client.close()
		udp_client = null
	print("Stopped discovery client")

func _process(_delta):
	# Handle server-side: respond to discovery requests
	if is_broadcasting and udp_server:
		while udp_server.get_available_packet_count() > 0:
			var packet = udp_server.get_packet()
			var sender_ip = udp_server.get_packet_ip()
			var sender_port = udp_server.get_packet_port()
			
			var message_str = packet.get_string_from_utf8()
			var message = JSON.parse_string(message_str)
			
			if message and message.get("type") == "discovery_request":
				_send_server_info(sender_ip, sender_port)
	
	# Handle client-side: receive server broadcasts
	if is_discovering and udp_client:
		while udp_client.get_available_packet_count() > 0:
			var packet = udp_client.get_packet()
			var sender_ip = udp_client.get_packet_ip()
			
			var message_str = packet.get_string_from_utf8()
			var server_info = JSON.parse_string(message_str)
			
			if server_info and server_info.get("type") == "server_info":
				server_info.ip = sender_ip
				emit_signal("server_discovered", server_info)

func _send_server_info(target_ip: String, _target_port: int):
	var response = current_server_info.duplicate()
	response["type"] = "server_info"
	response["ip"] = IP.get_local_addresses()[0]  # Get local IP
	
	var temp_udp = PacketPeerUDP.new()
	temp_udp.set_dest_address(target_ip, BROADCAST_PORT + 1)
	temp_udp.put_packet(JSON.stringify(response).to_utf8_buffer())
	temp_udp.close()

func _on_discovery_timer_timeout():
	if is_discovering:
		send_discovery_request()

# Update player count when someone joins/leaves
func update_player_count(count: int):
	if current_server_info.has("players"):
		current_server_info.players = count

func _exit_tree():
	stop_broadcasting()
	stop_discovery_client()
