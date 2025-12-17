class_name UserSettings
extends Resource

@export_range(0, 100, 10) var master_volume_level: int = 100
@export_range(0, 100, 10) var music_volume_level: int = 50
@export_range(0, 100, 10) var sfx_volume_level: int = 50
@export_enum("Windowed", "Fullscreen") var screen_mode = "Windowed"
@export_range(30, 240, 10) var fps_limit = 240
@export var vsync_on : bool

func save() -> void:
	ResourceSaver.save(self, "user://user_settings.tres")
	
static func load_or_create() -> UserSettings:
	var res: UserSettings = load("user://user_settings.tres") as UserSettings
	if !res:
		res = UserSettings.new()
	return res
