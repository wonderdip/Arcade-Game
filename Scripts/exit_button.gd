extends Button


func _on_pressed() -> void:
	if Networkhandler.is_local:
		get_tree().change_scene_to_file("res://Scenes/Menus/title_screen.tscn")
	else:
		Networkhandler._on_server_disconnected()
