extends Control

signal settings_deleted

@onready var game: Button = $Panel/VBoxContainer/Game
@onready var video: Button = $Panel/VBoxContainer/Video
@onready var audio: Button = $Panel/VBoxContainer/Audio
@onready var exit: Button = $Panel/VBoxContainer/Exit

@onready var game_panel: Panel = $Panel/GamePanel
@onready var video_panel: Panel = $Panel/VideoPanel
@onready var audio_panel: Panel = $Panel/AudioPanel

@onready var screen_mode: OptionButton = $Panel/VideoPanel/ScrollContainer/HBoxContainer/Buttons/ScreenMode
@onready var fps: SpinBox = $Panel/VideoPanel/ScrollContainer/HBoxContainer/Buttons/FPS
@onready var vsync: CheckBox = $Panel/VideoPanel/ScrollContainer/HBoxContainer/Buttons/Vysnc

@onready var master_vol: HSlider = $Panel/AudioPanel/ScrollContainer/HBoxContainer/VBoxContainer/MasterVol
@onready var music_vol: HSlider = $Panel/AudioPanel/ScrollContainer/HBoxContainer/VBoxContainer/MusicVol
@onready var sfx_vol: HSlider = $Panel/AudioPanel/ScrollContainer/HBoxContainer/VBoxContainer/SFXVol

@onready var launcher_on: Label = $Panel/GamePanel/ScrollContainer/HBoxContainer/Labels/LauncherOn
@onready var launcher_check: CheckBox = $Panel/GamePanel/ScrollContainer/HBoxContainer/Buttons/LauncherCheck
@onready var ball_launcher: Label = $Panel/GamePanel/ScrollContainer/HBoxContainer/Labels/BallLauncher
@onready var launcher_options: OptionButton = $Panel/GamePanel/ScrollContainer/HBoxContainer/Buttons/LauncherOptions

@onready var bot_check: CheckBox = $Panel/GamePanel/ScrollContainer/HBoxContainer/Buttons/BotCheck
@onready var bot_difficulty: OptionButton = $Panel/GamePanel/ScrollContainer/HBoxContainer/Buttons/BotDifficulty
@onready var bot_on: Label = $Panel/GamePanel/ScrollContainer/HBoxContainer/Labels/BotOn
@onready var difficulty: Label = $Panel/GamePanel/ScrollContainer/HBoxContainer/Labels/Difficulty

var launcher_instance: PackedScene = preload("res://Scenes/ball_launcher.tscn")
var bot_instance: PackedScene = preload("res://Scenes/bot.tscn")

var settings_button: Button = null
var exit_button_ui: Button = null

var user_settings: UserSettings

func _ready() -> void:
	# Get settings from the SettingsManager autoload
	user_settings = SettingsManager.get_settings()
	
	# Apply loaded settings to UI controls
	_load_settings_to_ui()
	
	video.grab_focus()
	get_tree().connect("node_added", _on_node_added)
	change_menu(2)
	
	_setup_spinbox_controller_input(fps)
	
	if Networkhandler.is_solo:
		change_menu(1)
		game.show()
		game.grab_focus()
		_setup_focus_neighbors()
		
		var existing_launcher = _find_existing_launcher()
		if existing_launcher:
			launcher_check.button_pressed = true
			var current_pos = _get_launcher_position_index(existing_launcher)
			launcher_options.selected = current_pos
		else:
			launcher_check.button_pressed = false
			
		# Check if bot exists and update checkbox
		var existing_bot = _find_bot()
		if existing_bot:
			bot_check.button_pressed = true
	else:
		game.hide()
	
	_disable_background_ui()
	call_deferred("_setup_focus_neighbors")

func _load_settings_to_ui() -> void:
	"""Load settings from resource and apply to UI controls"""
	# Audio settings
	if master_vol:
		master_vol.value = user_settings.master_volume_level
	if music_vol:
		music_vol.value = user_settings.music_volume_level
	if sfx_vol:
		sfx_vol.value = user_settings.sfx_volume_level
	
	# Video settings
	if screen_mode:
		screen_mode.selected = user_settings.screen_mode
	if fps:
		fps.value = user_settings.fps_limit
	if vsync:
		vsync.button_pressed = user_settings.vsync_on
	
	# Bot settings
	if bot_difficulty:
		bot_difficulty.selected = user_settings.bot_difficulty

func _save_settings() -> void:
	"""Save current settings to disk"""
	SettingsManager.save_settings()
	print("Settings saved to disk")

func _process(_delta: float) -> void:
	if !exit.has_focus() and Input.is_action_just_pressed("exit_ui") and !fps.has_focus():
		exit.grab_focus()

func _disable_background_ui():
	var in_game_ui = get_tree().current_scene.find_child("InGame_UI", true, false)
	if in_game_ui:
		settings_button = in_game_ui.find_child("Settings button", true, false)
		exit_button_ui = in_game_ui.find_child("Exit_Button", true, false)
		
		if settings_button:
			settings_button.focus_mode = Control.FOCUS_NONE
		if exit_button_ui:
			exit_button_ui.focus_mode = Control.FOCUS_NONE

func _restore_background_ui():
	if settings_button:
		settings_button.focus_mode = Control.FOCUS_ALL
	if exit_button_ui:
		exit_button_ui.focus_mode = Control.FOCUS_ALL

func _setup_focus_neighbors():
	# Game panel focus
	game.focus_neighbor_right = launcher_check.get_path()
	launcher_check.focus_neighbor_left = game.get_path()
	launcher_check.focus_neighbor_right = launcher_options.get_path()
	launcher_options.focus_neighbor_left = launcher_check.get_path()
	launcher_options.focus_neighbor_bottom = bot_check.get_path()
	
	bot_check.focus_neighbor_left = game.get_path()
	bot_check.focus_neighbor_top = launcher_check.get_path()
	
	# Video panel focus
	video.focus_neighbor_right = screen_mode.get_path()
	screen_mode.focus_neighbor_left = video.get_path()
	screen_mode.focus_neighbor_bottom = fps.get_path()
	
	fps.focus_neighbor_left = video.get_path()
	fps.focus_neighbor_top = screen_mode.get_path()
	fps.focus_neighbor_bottom = vsync.get_path()
	
	vsync.focus_neighbor_left = video.get_path()
	vsync.focus_neighbor_top = fps.get_path()
	
	# Audio panel focus
	audio.focus_neighbor_right = master_vol.get_path()
	master_vol.focus_neighbor_left = audio.get_path()
	master_vol.focus_neighbor_bottom = music_vol.get_path()
	music_vol.focus_neighbor_left = audio.get_path()
	music_vol.focus_neighbor_top = master_vol.get_path()
	music_vol.focus_neighbor_bottom = sfx_vol.get_path()
	sfx_vol.focus_neighbor_left = audio.get_path()
	sfx_vol.focus_neighbor_top = music_vol.get_path()

func _get_spinbox_line_edit(spinbox: SpinBox) -> LineEdit:
	for child in spinbox.get_children():
		if child is LineEdit:
			return child
	return null

func _setup_spinbox_controller_input(spinbox: SpinBox):
	var line_edit = _get_spinbox_line_edit(spinbox)
	if line_edit:
		line_edit.focus_mode = Control.FOCUS_NONE
		line_edit.mouse_filter = Control.MOUSE_FILTER_PASS
	
	spinbox.focus_mode = Control.FOCUS_ALL
	
	if not spinbox.focus_entered.is_connected(_on_fps_focus_entered):
		spinbox.focus_entered.connect(_on_fps_focus_entered)

func _on_fps_focus_entered():
	fps.grab_focus()

func _on_node_added(node: Node) -> void:
	if node is PopupPanel and node.name.begins_with("@PopupPanel@"):
		node.queue_free()

# ========================================
# LAUNCHER FUNCTIONS
# ========================================

func _on_launcher_check_toggled(toggled_on: bool) -> void:
	if toggled_on:
		ball_launcher.show()
		launcher_options.show()
		if bot_check.button_pressed:
			_remove_bot()
			bot_check.button_pressed = false
		_spawn_launcher()
	else:
		_remove_launcher()
		ball_launcher.hide()
		launcher_options.hide()
func _on_launcher_options_item_selected(index: int) -> void:
	var existing_launcher = _find_existing_launcher()
	if existing_launcher:
		existing_launcher.change_position(index + 1)

func _find_existing_launcher() -> Node:
	var world = get_tree().current_scene
	if world:
		for child in world.get_children():
			if child.name == "Ball_Launcher":
				return child
	return null

func _get_launcher_position_index(launcher: Node) -> int:
	if launcher.position.distance_to(Vector2(190, 45)) < 5:
		return 0
	elif launcher.position.distance_to(Vector2(158, 37)) < 5:
		return 1
	elif launcher.position.distance_to(Vector2(55, 100)) < 5:
		return 2
	return 0

func _spawn_launcher() -> void:
	var existing_launcher = _find_existing_launcher()
	if existing_launcher:
		return
	
	var new_launcher = launcher_instance.instantiate()
	new_launcher.name = "Ball_Launcher"
	get_tree().current_scene.add_child(new_launcher, true)
	await get_tree().process_frame
	new_launcher.change_position(launcher_options.selected + 1)

func _remove_launcher() -> void:
	var existing_launcher = _find_existing_launcher()
	if existing_launcher and existing_launcher.is_inside_tree():
		existing_launcher.delete_all_balls()
		existing_launcher.queue_free()

# ========================================
# BOT FUNCTIONS
# ========================================

func _find_bot():
	var world = get_tree().current_scene
	if world:
		for child in world.get_children():
			if child.name == "Bot":
				return child
	return null
	
func _spawn_bot():
	var existing_bot = _find_bot()
	if existing_bot:
		return
	
	var new_bot = bot_instance.instantiate()
	new_bot.name = "Bot"
	get_tree().current_scene.add_child(new_bot, true)
	await get_tree().process_frame
	new_bot.global_position = Vector2(236, 112)
	
	# Apply saved settings to the bot
	new_bot.set_difficulty_from_index(user_settings.bot_difficulty)
	print("Spawned bot with difficulty:", _get_difficulty_name(user_settings.bot_difficulty))
	
func _remove_bot():
	var existing_bot = _find_bot()
	if existing_bot and existing_bot.is_inside_tree():
		existing_bot.queue_free()

func _get_difficulty_name(index: int) -> String:
	match index:
		0: return "Easy"
		1: return "Normal"
		2: return "Hard"
		3: return "Expert"
		_: return "Normal"

func _on_bot_check_toggled(toggled_on: bool) -> void:
	if toggled_on:
		bot_difficulty.show()
		difficulty.show()
		if launcher_check.button_pressed:
			_remove_launcher()
			launcher_check.button_pressed = false
		_spawn_bot()
	else:
		bot_difficulty.hide()
		difficulty.hide()
		_remove_bot()
		 
func _on_bot_difficulty_item_selected(index: int) -> void:
	user_settings.bot_difficulty = index
	_save_settings()
	
	# Update existing bot if spawned
	var existing_bot = _find_bot()
	if existing_bot:
		existing_bot.set_difficulty_from_index(index)
		print("Updated bot difficulty to:", _get_difficulty_name(index))

# ========================================
# MENU NAVIGATION
# ========================================

func _on_game_pressed() -> void:
	change_menu(1)

func _on_video_pressed() -> void:
	change_menu(2)

func _on_audio_pressed() -> void:
	change_menu(3)

func _on_exit_pressed() -> void:
	_save_settings()  # Save before closing
	queue_free()
	_restore_background_ui()
	emit_signal("settings_deleted")

func change_menu(current_menu: int):
	game_panel.visible = current_menu == 1
	video_panel.visible = current_menu == 2
	audio_panel.visible = current_menu == 3
	
	match current_menu:
		1:
			if Networkhandler.is_solo:
				game.focus_neighbor_right = launcher_check.get_path()
				launcher_check.grab_focus()
			else:
				game.focus_neighbor_right = NodePath()
		2:
			video.focus_neighbor_right = screen_mode.get_path()
			screen_mode.grab_focus()
		3:
			audio.focus_neighbor_right = master_vol.get_path()
			master_vol.grab_focus()

func _center_on_screen() -> void:
	var screen_size = get_viewport_rect().size
	global_position = screen_size / 2 - size / 2

# ========================================
# VIDEO SETTINGS CALLBACKS
# ========================================

func _on_screen_mode_item_selected(index: int) -> void:
	user_settings.screen_mode = index
	if index == 1:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	_save_settings()

func _on_fps_value_changed(value: int) -> void:
	user_settings.fps_limit = int(value)
	Engine.max_fps = int(value)
	_save_settings()

func _on_vysnc_toggled(toggled_on: bool) -> void:
	user_settings.vsync_on = toggled_on
	if toggled_on:
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED)
	else:
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	_save_settings()

# ========================================
# AUDIO SETTINGS CALLBACKS
# ========================================

func _on_master_vol_value_changed(value) -> void:
	user_settings.master_volume_level = int(value)
	AudioManager.change_master_vol(value)
	_save_settings()

func _on_sfx_vol_value_changed(value) -> void:
	user_settings.sfx_volume_level = int(value)
	AudioManager.change_sfx_vol(value)
	_save_settings()

func _on_music_vol_value_changed(value) -> void:
	user_settings.music_volume_level = int(value)
	AudioManager.change_music_vol(value)
	_save_settings()
