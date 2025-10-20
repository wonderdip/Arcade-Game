extends Control

signal settings_deleted

@onready var game_panel: Panel = $Panel/GamePanel
@onready var video_panel: Panel = $Panel/VideoPanel
@onready var audio_panel: Panel = $Panel/AudioPanel
@onready var screen_mode: OptionButton = $Panel/VideoPanel/ScrollContainer/HBoxContainer/Buttons/ScreenMode
@onready var fps: SpinBox = $Panel/VideoPanel/ScrollContainer/HBoxContainer/Buttons/FPS
@onready var master_vol: HSlider = $Panel/AudioPanel/ScrollContainer/HBoxContainer/VBoxContainer/MasterVol
@onready var music_vol: HSlider = $Panel/AudioPanel/ScrollContainer/HBoxContainer/VBoxContainer/MusicVol
@onready var sfx_vol: HSlider = $Panel/AudioPanel/ScrollContainer/HBoxContainer/VBoxContainer/SFXVol

func _ready() -> void:
	get_tree().connect("node_added", _on_node_added)
	change_menu(1)
	fps.value = Engine.max_fps
	master_vol.value = 50
	music_vol.value = 50
	sfx_vol.value = 50
	
func _on_node_added(node: Node) -> void:
	if node is PopupPanel and node.name.begins_with("@PopupPanel@"):
		node.queue_free()

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
	
	if current_menu == 1:
		game_panel.show()
		video_panel.hide()
		audio_panel.hide()
	elif current_menu == 2:
		game_panel.hide()
		video_panel.show()
		audio_panel.hide()
	elif current_menu == 3:
		game_panel.hide()
		video_panel.hide()
		audio_panel.show()
	
func _center_on_screen() -> void:
	var screen_size = get_viewport_rect().size
	global_position = screen_size / 2 - size / 2
	
func _on_screen_mode_item_selected(index: int) -> void:
	if index == 0:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	if index == 1:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)

func _on_fps_value_changed(value: int) -> void:
	Engine.max_fps = value

func _on_vysnc_toggled(toggled_on: bool) -> void:
	if toggled_on:
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED)
	else:
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)

func _on_master_vol_value_changed(value: int) -> void:
	pass

func _on_sfx_vol_value_changed(value) -> void:
	AudioManager.change_sfx_vol(value)
