extends Button
@onready var timer: Timer = $Timer

func _on_pressed() -> void:
	disabled = true
	timer.start()
	
	if Networkhandler.is_local:
		get_tree().change_scene_to_file("res://Scenes/Menus/title_screen.tscn")
		Networkhandler.is_local = false
		Networkhandler.is_solo = false
		LocalPlayerManager.reset()
	elif Networkhandler.is_solo:
		get_tree().change_scene_to_file("res://Scenes/Menus/singleplayer_menu.tscn")
		Networkhandler.is_solo = false
	elif get_tree().current_scene.name != "World":
		get_tree().quit()
	elif Networkhandler.is_local == false or Networkhandler.is_solo == false:
		Networkhandler._on_server_disconnected()
	else:
		get_tree().quit()


func _on_timer_timeout() -> void:
	disabled = false
