class_name UserSettings
extends Resource

@export_range(0, 100, 10) var master_volume_level: int = 100
@export_range(0, 100, 10) var music_volume_level: int = 50
@export_range(0, 100, 10) var sfx_volume_level: int = 50
@export_range(0, 1) var screen_mode: int = 0  # 0 = Windowed, 1 = Fullscreen
@export_range(30, 240, 10) var fps_limit: int = 240
@export var vsync_on: bool = false

@export_range(0, 3) var bot_difficulty: int = 1  # 0=Easy, 1=Normal, 2=Hard, 3=Expert

func save() -> void:
	var error = ResourceSaver.save(self, "user://user_settings.tres")
	if error != OK:
		push_error("Failed to save user settings: " + str(error))
	else:
		print("User settings saved successfully")
	
static func load_or_create() -> UserSettings:
	var path = "user://user_settings.tres"
	if ResourceLoader.exists(path):
		var loaded = ResourceLoader.load(path)
		if loaded is UserSettings:
			print("User settings loaded from file")
			return loaded
		else:
			push_warning("Invalid settings file, creating new one")
	
	print("Creating new user settings")
	var res = UserSettings.new()
	res.save()  # Save default settings
	return res
