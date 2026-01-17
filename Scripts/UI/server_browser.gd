extends Control

@onready var server_list: ItemList = $ScrollContainer/VBoxContainer/ServerList
@onready var join_button: Button = $ScrollContainer/VBoxContainer/HBoxContainer/JoinButton
@onready var refresh_button: Button = $ScrollContainer/VBoxContainer/HBoxContainer/Refresh
@onready var status_label: Label = $ScrollContainer/VBoxContainer/StatusLabel

var discovered_servers = {}
var selected_server_ip = ""
var searching := false
var search_start_time := 0

func _ready():
	print("[Browser] Server browser ready")
	join_button.grab_focus()
	join_button.disabled = true
	
	# Connect to discovery signal
	if not ServerDiscovery.server_discovered.is_connected(_on_server_discovered):
		ServerDiscovery.server_discovered.connect(_on_server_discovered)
	
	# Start discovery automatically
	refresh_servers()

func _on_server_discovered(server_info: Dictionary):
	print("[Browser] Discovered server:", server_info)
	
	var server_key = server_info.ip + ":" + str(server_info.port)
	discovered_servers[server_key] = server_info
	_update_server_list()

func _update_server_list():
	server_list.clear()
	
	if discovered_servers.is_empty():
		status_label.text = "No servers found"
		join_button.disabled = true
		return
	
	status_label.text = "Found %d server(s)" % discovered_servers.size()
	
	for key in discovered_servers:
		var server = discovered_servers[key]
		var display_text = ""
		
		if server.has("name"):
			display_text += server.name
		else:
			display_text += "[Unnamed]"
		
		display_text += " (%d/%d)" % [
			int(server.get("players", 0)),
			int(server.get("max_players", 2))
		]
		display_text += " - " + server.ip
		
		server_list.add_item(display_text)
		server_list.set_item_metadata(server_list.get_item_count() - 1, server)
	
	# Auto-select first server
	if server_list.item_count > 0:
		server_list.select(0)
		_on_server_list_item_selected(0)

func _on_server_list_item_selected(index: int):
	var server_info = server_list.get_item_metadata(index)
	if server_info:
		selected_server_ip = server_info.ip
		join_button.disabled = false
		print("[Browser] Selected server:", server_info)

func _on_join_button_pressed():
	var selected_items = server_list.get_selected_items()
	AudioManager.play_sfx("click")
	
	if selected_items.size() == 0:
		print("[Browser] No server selected")
		return
	
	var selected_index = selected_items[0]
	var server_info = server_list.get_item_metadata(selected_index)
	
	print("[Browser] Joining server at %s:%d" % [server_info.ip, server_info.port])
	
	ServerDiscovery.stop_discovery_client()
	Networkhandler.join_server(server_info.ip, server_info.port)

func _on_refresh_button_pressed():
	refresh_servers()
	AudioManager.play_sfx("click")

func refresh_servers():
	print("[Browser] Starting server search...")
	
	discovered_servers.clear()
	server_list.clear()
	searching = true
	search_start_time = Time.get_ticks_msec()
	join_button.disabled = true
	
	animate_search_label()
	
	# Stop any existing discovery
	ServerDiscovery.stop_discovery_client()
	
	# Wait a frame
	await get_tree().process_frame
	
	# Start new discovery
	ServerDiscovery.start_discovery_client()
	
	# Send multiple discovery requests over time
	for i in range(5):  # 5 attempts over 5 seconds
		print("[Browser] Discovery attempt %d/5" % (i + 1))
		ServerDiscovery.send_discovery_request()
		await get_tree().create_timer(1.0).timeout
	
	searching = false
	
	var search_time = (Time.get_ticks_msec() - search_start_time) / 1000.0
	print("[Browser] Search complete after %.1f seconds" % search_time)
	
	if discovered_servers.is_empty():
		status_label.text = "No servers found"
		print("[Browser] No servers discovered")
	else:
		status_label.text = "Found %d server(s)" % discovered_servers.size()
		print("[Browser] Found %d server(s)" % discovered_servers.size())
	
	hide_label()

func hide_label():
	if not searching:
		await get_tree().create_timer(2.0).timeout
		if not searching:  # Check again in case refresh was pressed
			status_label.visible = true  # Keep it visible to show result

func animate_search_label() -> void:
	await get_tree().process_frame
	var dot_count := 0
	while searching:
		dot_count = (dot_count + 1) % 4
		status_label.visible = true
		status_label.text = "Searching" + ".".repeat(dot_count)
		await get_tree().create_timer(0.5).timeout

func _on_back_button_pressed():
	print("[Browser] Returning to main menu")
	ServerDiscovery.stop_discovery_client()
	get_tree().change_scene_to_file("res://Scenes/Menus/title_screen.tscn")
	AudioManager.play_sfx("click")

func _exit_tree():
	print("[Browser] Exiting browser")
	ServerDiscovery.stop_discovery_client()
