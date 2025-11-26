extends Button

@export var settings_menu: PackedScene

func _on_pressed() -> void:
	var settings_menu_instance = settings_menu.instantiate()
	add_child(settings_menu_instance)
	
	# Center it after it enters the scene tree
	settings_menu_instance.call_deferred("_center_on_screen")
	settings_menu_instance.connect("settings_deleted", enable)
	disabled = true

func enable():
	disabled = false
	grab_focus()
