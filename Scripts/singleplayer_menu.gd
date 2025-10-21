extends Control


func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://Scenes/Menus/title_screen.tscn")
	AudioManager.play_sound_from_library("click")
	
func _on_training_pressed() -> void:
	get_tree().change_scene_to_file("res://Scenes/world.tscn")
	Networkhandler.is_solo = true
	AudioManager.play_sound_from_library("click")
