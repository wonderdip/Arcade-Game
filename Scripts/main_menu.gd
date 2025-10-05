extends Control

func _on_server_pressed() -> void:
	Networkhandler.is_local = false
	Networkhandler.start_server()

func _on_local_pressed() -> void:
	# Clear any previous network connections
	if multiplayer.multiplayer_peer != null:
		multiplayer.multiplayer_peer.close()
		multiplayer.multiplayer_peer = null
	
	Networkhandler.is_local = true
	get_tree().change_scene_to_file("res://Scenes/world.tscn")

func _on_join_pressed() -> void:
	Networkhandler.is_local = false
	Networkhandler.start_client()


func _on_single_player_pressed() -> void:
	get_tree().change_scene_to_file("res://Scenes/world.tscn")
