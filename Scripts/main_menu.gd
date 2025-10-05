extends Control

func _on_server_pressed() -> void:
	Networkhandler.start_server()

func _on_button_pressed() -> void:
	get_tree().change_scene_to_file("res://Scenes/world.tscn")
	Networkhandler.is_local = true

func _on_join_pressed() -> void:
	Networkhandler.start_client()
