extends Control

var player_number = 1

var first_player_chose: bool = 0
var second_player_chose: bool = 0

@onready var p_1: Button = $BasePanel/BaseVbox/HBoxContainer/CharVboc/FirstRow/P1
@onready var p_2: Button = $BasePanel/BaseVbox/HBoxContainer/CharVboc/FirstRow/P2
@onready var p_3: Button = $BasePanel/BaseVbox/HBoxContainer/CharVboc/SecondRow/P3

@export var characters: Array[CharacterStat]
@onready var player_choice: Button = $BasePanel/BaseVbox/HBoxContainer/CharVboc/PlayerChoice
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
	change_sliders()
	
func _on_p_1_pressed() -> void:
	current_selection = characters.get(0)
	change_sliders()
	
func _on_p_2_pressed() -> void:
	current_selection = characters.get(1)
	
func _on_p_3_pressed() -> void:
	current_selection = characters.get(2)

func change_sliders():
	speed_slider.value = current_selection.Speed
	jumping_slider.value = current_selection.Jumping
	hitting_slider.value = current_selection.Hitting
	setting_slider.value = current_selection.Setting
	recieving_slider.value = current_selection.Recieving * 2
	blocking_slider.value = current_selection.Blocking
	
	player_choice.text = "Choose: " + current_selection.name
	
