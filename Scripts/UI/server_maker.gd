extends Control

@onready var server_name: LineEdit = $VBoxContainer/ServerName
@onready var player_number: HSlider = $VBoxContainer/HBoxContainer2/PlayerSlider
@onready var max_players: Label = $VBoxContainer/HBoxContainer2/MaxPlayers

func _ready() -> void:
	server_name.grab_focus()
	
func _on_confirm_pressed() -> void:
	if server_name.text.strip_edges().length() == 0:
		name = "Unnamed Server"
	else:
		name = server_name.text
	Networkhandler.is_local = false
	Networkhandler.is_solo = false
	Networkhandler.start_server(name)

func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://Scenes/Menus/title_screen.tscn")

func _on_player_slider_value_changed(value: int) -> void:
	max_players.text = "Max Players: " + str(value)
