extends Control

@onready var server_list: ItemList = $ScrollContainer/VBoxContainer/ServerList
@onready var join_button: Button = $ScrollContainer/VBoxContainer/HBoxContainer/JoinButton
@onready var status_label: Label = $ScrollContainer/VBoxContainer/StatusLabel
@onready var manual_ip_input: LineEdit = $ScrollContainer/VBoxContainer/ManualConnect/IPInput
@onready var manual_connect_button: Button = $ScrollContainer/VBoxContainer/ManualConnect/ConnectButton

var discovered_servers = {}  # Dictionary to store server info
var selected_server_ip = ""
var searching := false

func _ready():
	# Start searching for servers when the scene loads
	ServerDiscovery.server_discovered.connect(_on_server_discovered)
	ServerDiscovery.start_discovery_client()
	refresh_servers()
	
func _on_server_discovered(server_info: Dictionary):
	print("Discovered server:", server_info)
	var server_key = server_info.ip + ":" + str(server_info.port)
	discovered_servers[server_key] = server_info
	_update_server_list()

	
func _update_server_list():
	server_list.clear()
	if discovered_servers.is_empty():
		status_label.text = "No servers found"
		join_button.disabled = true
		return
	status_label.text = "Found " + str(discovered_servers.size()) + " server(s)"
	for key in discovered_servers:
		var server = discovered_servers[key]
		var display_text = ""
		if server.has("name"):
			display_text += server.name
		else:
			display_text += "[Unnamed]"
		display_text += " (" + str(snapped(server["players"], 1)) + "/" + str(snapped(server["max_players"], 1)) + ")"
		server_list.add_item(display_text)
		server_list.set_item_metadata(server_list.get_item_count() - 1, server)

func _on_server_list_item_selected(index: int):
	var server_info = server_list.get_item_metadata(index)
	if server_info:
		selected_server_ip = server_info.ip
		join_button.disabled = false
		print("Selected server:", server_info)
		
func _on_join_button_pressed():
	var selected_items = server_list.get_selected_items()
	if selected_items.size() == 0:
		print("No server selected.")
		return
	var selected_index = selected_items[0]
	var server_info = server_list.get_item_metadata(selected_index)
	ServerDiscovery.stop_discovery_client()
	Networkhandler.join_server(server_info.ip, server_info.port)

func _on_manual_connect_pressed():
	var ip_text = manual_ip_input.text.strip_edges()
	if ip_text.is_empty():
		status_label.text = "Enter IP address"
		return
	
	# Parse IP and port (format: "10.0.0.218" or "10.0.0.218:41677")
	var parts = ip_text.split(":")
	var ip = parts[0]
	var port = Networkhandler.DEFAULT_PORT
	
	if parts.size() > 1:
		port = int(parts[1])
	
	print("Manual connect to: %s:%d" % [ip, port])
	ServerDiscovery.stop_discovery_client()
	Networkhandler.join_server(ip, port)

func _on_refresh_button_pressed():
	refresh_servers()

func refresh_servers():
	discovered_servers.clear()
	server_list.clear()
	join_button.disabled = true
	status_label.text = "Searching"
	searching = true
	animate_search_label()
	
	if not ServerDiscovery.is_discovering:
		ServerDiscovery.start_discovery_client()
	
	# Send several discovery requests over time
	for i in range(3):  # try 3 times over ~3 seconds
		ServerDiscovery.send_discovery_request()
		await get_tree().create_timer(1.0).timeout
	
	searching = false
	if discovered_servers.is_empty():
		status_label.text = "No servers found"
	else:
		status_label.text = "Search done (" + str(discovered_servers.size()) + " found)"

func animate_search_label() -> void:
	await get_tree().process_frame  # allow UI to update
	var dot_count := 0
	while searching:
		dot_count = (dot_count + 1) % 4  # cycles 0–3
		status_label.text = "Searching" + ".".repeat(dot_count)
		await get_tree().create_timer(0.5).timeout
		

func _on_back_button_pressed():
	ServerDiscovery.stop_discovery_client()
	get_tree().change_scene_to_file("res://Scenes/Menus/title_screen.tscn")

func _exit_tree():
	ServerDiscovery.stop_discovery_client()
