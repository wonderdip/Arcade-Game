extends Control

signal settings_deleted

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

var launcher_instance: PackedScene = preload("res://Scenes/ball_launcher.tscn")
var is_launcher_on: bool = false
var current_launcher: Node = null


func _ready() -> void:
	get_tree().connect("node_added", _on_node_added)
	change_menu(1)
	
	fps.value = Engine.max_fps
	master_vol.value = AudioManager.master_vol
	music_vol.value = AudioManager.music_vol
	sfx_vol.value = AudioManager.sfx_vol
		
	var mode = DisplayServer.window_get_mode()
	if mode == DisplayServer.WINDOW_MODE_FULLSCREEN:
		screen_mode.selected = 1
	else:
		screen_mode.selected = 0
		
	var vsync_mode = DisplayServer.window_get_vsync_mode()
	vsync.button_pressed = (vsync_mode == DisplayServer.VSYNC_ENABLED)
	
	if Networkhandler.is_solo:
		launcher_on.show()
		launcher_check.show()
		ball_launcher.show()
		launcher_options.show()
		
		if is_launcher_on:
			# Restore existing launcher if the setting was left on
			_spawn_launcher()
			launcher_check.button_pressed = true
	else:
		launcher_on.hide()
		launcher_check.hide()
		ball_launcher.hide()
		launcher_options.hide()


func _on_node_added(node: Node) -> void:
	if node is PopupPanel and node.name.begins_with("@PopupPanel@"):
		node.queue_free()


func _on_launcher_check_toggled(toggled_on: bool) -> void:
	if toggled_on:
		_spawn_launcher()
	else:
		_remove_launcher()

func _spawn_launcher() -> void:
	if current_launcher:
		_remove_launcher()
	
	current_launcher = launcher_instance.instantiate()
	current_launcher.change_position(launcher_options.selected + 1)
	get_tree().current_scene.add_child(current_launcher, true)
	is_launcher_on = true

func _remove_launcher() -> void:
	if current_launcher and current_launcher.is_inside_tree():
		current_launcher.queue_free()
		current_launcher = null
	is_launcher_on = false
	
func _on_game_pressed() -> void:
	change_menu(1)

func _on_video_pressed() -> void:
	change_menu(2)

func _on_audio_pressed() -> void:
	change_menu(3)

func _on_exit_pressed() -> void:
	emit_signal("settings_deleted")
	queue_free()


func change_menu(current_menu: int):
	game_panel.visible = current_menu == 1
	video_panel.visible = current_menu == 2
	audio_panel.visible = current_menu == 3


func _center_on_screen() -> void:
	var screen_size = get_viewport_rect().size
	global_position = screen_size / 2 - size / 2


func _on_screen_mode_item_selected(index: int) -> void:
	if index == 1:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)


func _on_fps_value_changed(value: int) -> void:
	Engine.max_fps = value


func _on_vysnc_toggled(toggled_on: bool) -> void:
	if toggled_on:
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED)
	else:
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)

func _on_master_vol_value_changed(value) -> void:
	AudioManager.change_master_vol(value)

func _on_sfx_vol_value_changed(value) -> void:
	AudioManager.change_sfx_vol(value)

func _on_music_vol_value_changed(value) -> void:
	AudioManager.change_music_vol(value)
