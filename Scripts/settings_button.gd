extends Button

@export var settings_menu: PackedScene

func _on_pressed() -> void:
	open_settings()

func enable():
	disabled = false
	grab_focus()
	
func open_settings():
	var settings_menu_instance = settings_menu.instantiate()
	
	add_child(settings_menu_instance)
	
	# Center it after it enters the scene tree
	settings_menu_instance.call_deferred("_center_on_screen")
	disabled = true

	return settings_menu_instance
