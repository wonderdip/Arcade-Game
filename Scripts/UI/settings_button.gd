extends Button

signal settings_opened

@export var settings_menu: PackedScene


func _ready() -> void:
	SettingsManager.connect("open_settings", open_settings)

func _on_pressed() -> void:
	open_settings()

func enable():
	disabled = false
	await get_tree().process_frame
	SettingsManager.settings_opened = false   # <— UNFREEZE
	
	if get_child_count() > 0:
		get_child(0).queue_free()
	
func open_settings():
	SettingsManager.settings_opened = true
	var settings_menu_instance = settings_menu.instantiate()
	
	add_child(settings_menu_instance)
	emit_signal("settings_opened")
	
	# Center it after it enters the scene tree
	settings_menu_instance.call_deferred("_center_on_screen")
	settings_menu_instance.connect("settings_deleted", enable)
	disabled = true

	return settings_menu_instance
