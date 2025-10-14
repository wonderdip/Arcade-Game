extends Control

@onready var server_name: LineEdit = $VBoxContainer/ServerName

func _on_confirm_pressed() -> void:
	if server_name.text.strip_edges().length() == 0:
		name = "Unnamed Server"
	else:
		name = server_name.text
	Networkhandler.is_local = false
	Networkhandler.start_server(name)

func _on_spin_box_value_changed(value: int) -> void:
	Networkhandler.MAX_CLIENTS = value


func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://Scenes/Menus/title_screen.tscn")
