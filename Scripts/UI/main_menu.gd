extends Control

# Add a popup for server name input
var server_name_dialog: AcceptDialog
var server_name_input: LineEdit

@onready var local: Button = $Server/Local

func _ready() -> void:
	Networkhandler.is_local = false
	Networkhandler.is_solo = false
	local.grab_focus()
	
func _on_server_pressed() -> void:
	get_tree().change_scene_to_file("res://Scenes/Menus/server_maker.tscn")
	AudioManager.play_sfx("click")

func _on_local_pressed() -> void:
	# Clear any previous network connections
	if multiplayer.multiplayer_peer != null:
		multiplayer.multiplayer_peer.close()
		multiplayer.multiplayer_peer = null
	
	Networkhandler.is_local = true
	get_tree().change_scene_to_file("res://Scenes/Menus/character_screen.tscn")
	AudioManager.play_sfx("click")

func _on_join_pressed() -> void:
	Networkhandler.is_local = false
	Networkhandler.start_client()  # This now opens the server browser
	AudioManager.play_sfx("click")

func _on_solo_pressed() -> void:
	get_tree().change_scene_to_file("res://Scenes/Menus/singleplayer_menu.tscn")
	AudioManager.play_sfx("click")
