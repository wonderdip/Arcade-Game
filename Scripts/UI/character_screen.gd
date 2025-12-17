extends Control

var current_player_selecting: int = 1  # Track which player is currently selecting

@onready var p_1: Button = $BasePanel/BaseVbox/HBoxContainer/CharVboc/FirstRow/P1
@onready var p_2: Button = $BasePanel/BaseVbox/HBoxContainer/CharVboc/FirstRow/P2
@onready var p_3: Button = $BasePanel/BaseVbox/HBoxContainer/CharVboc/SecondRow/P3

@export var characters: Array[CharacterStat]
@onready var player_choice: Button = $BasePanel/BaseVbox/HBoxContainer/CharVboc/PlayerChoice
@onready var title: Label = $BasePanel/BaseVbox/Title
@onready var speed_slider: HSlider = $BasePanel/BaseVbox/HBoxContainer/Stats/Statspanel/HBoxContainer/LeftSide/SpeedSlider
@onready var hitting_slider: HSlider = $BasePanel/BaseVbox/HBoxContainer/Stats/Statspanel/HBoxContainer/LeftSide/HittingSlider
@onready var recieving_slider: HSlider = $BasePanel/BaseVbox/HBoxContainer/Stats/Statspanel/HBoxContainer/LeftSide/RecievingSlider
@onready var jumping_slider: HSlider = $BasePanel/BaseVbox/HBoxContainer/Stats/Statspanel/HBoxContainer/RightSide/JumpingSlider
@onready var blocking_slider: HSlider = $BasePanel/BaseVbox/HBoxContainer/Stats/Statspanel/HBoxContainer/RightSide/BlockingSlider
@onready var setting_slider: HSlider = $BasePanel/BaseVbox/HBoxContainer/Stats/Statspanel/HBoxContainer/RightSide/SettingSlider

var current_selection: CharacterStat

func _ready() -> void:
	p_1.grab_focus()
	current_selection = characters.get(0)
	change_values()
	update_title()
	
func _on_p_1_pressed() -> void:
	current_selection = characters.get(0)
	change_values()
	AudioManager.play_sound_from_library("click")
	
func _on_p_2_pressed() -> void:
	current_selection = characters.get(1)
	change_values()
	AudioManager.play_sound_from_library("click")
	
func _on_p_3_pressed() -> void:
	current_selection = characters.get(2)
	change_values()
	AudioManager.play_sound_from_library("click")
	
func change_values():
	speed_slider.value = current_selection.Speed
	jumping_slider.value = current_selection.Jumping
	hitting_slider.value = current_selection.Hitting
	setting_slider.value = current_selection.Setting
	recieving_slider.value = current_selection.Recieving
	blocking_slider.value = current_selection.Blocking
	
	player_choice.text = "Choose: " + current_selection.name

func update_title():
	if Networkhandler.is_local:
		title.text = "Player %d - Choose" % current_player_selecting
	else:
		title.text = "Choose your Player"
	
func _on_player_choice_pressed() -> void:
	AudioManager.play_sound_from_library("click")
	
	if Networkhandler.is_local:
		# Store the selection for the current player
		PlayerManager.set_player_character(current_player_selecting, current_selection)
		
		# If this was player 1, move to player 2 selection
		if current_player_selecting == 1:
			current_player_selecting = 2
			current_selection = characters.get(0)  # Reset to first character for P2
			change_values()
			update_title()
			p_1.grab_focus()
			print("Player 1 selection complete. Now selecting for Player 2.")
		else:
			# Both players have selected, proceed to game
			PlayerManager.ready_to_accept_players = true
			get_tree().change_scene_to_file("res://Scenes/world.tscn")
			print("Both players selected. Starting game.")
			
	elif Networkhandler.is_solo:
		PlayerManager.character = current_selection
		get_tree().change_scene_to_file("res://Scenes/world.tscn")
