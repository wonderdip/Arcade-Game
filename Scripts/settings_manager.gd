extends Node

signal open_settings
signal close_settings

var user_settings: UserSettings
var settings_opened: bool = false
	
func _ready() -> void:
	# Load settings as soon as the game starts
	user_settings = UserSettings.load_or_create()
	apply_settings()
	print("Settings loaded and applied on game start")
	
func apply_settings() -> void:
	"""Apply all settings to the game engine/systems"""
	# Apply audio settings
	AudioManager.set_bus_volume("Master", user_settings.master_volume_level)
	AudioManager.set_bus_volume("Music", user_settings.music_volume_level)
	AudioManager.set_bus_volume("SFX", user_settings.sfx_volume_level)
	
	# Apply video settings
	Engine.max_fps = user_settings.fps_limit
	
	if user_settings.screen_mode == 1:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	
	if user_settings.vsync_on:
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED)
	else:
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)

func save_settings() -> void:
	"""Save current settings to disk"""
	user_settings.save()
	print("Settings saved to disk")

func get_settings() -> UserSettings:
	"""Get the current settings resource"""
	return user_settings

func _input(event: InputEvent) -> void:
	
	if event.is_action_pressed("settings") and settings_opened:
		emit_signal("close_settings")
		
	elif event.is_action_pressed("settings") and not settings_opened:
		emit_signal("open_settings")
