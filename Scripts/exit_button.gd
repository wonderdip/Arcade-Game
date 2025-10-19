extends Button

func _on_pressed() -> void:
	if Networkhandler.is_local or Networkhandler.is_solo:
		get_tree().change_scene_to_file("res://Scenes/Menus/title_screen.tscn")
		Networkhandler.is_local = false
		Networkhandler.is_solo = false
	elif get_tree().current_scene.name == "TitleScreen":
		get_tree().quit()
	elif Networkhandler.is_local == false or Networkhandler.is_solo == false:
		Networkhandler._on_server_disconnected()
	else:
		return
