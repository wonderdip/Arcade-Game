extends Node

@onready var click_player: AudioStreamPlayer2D = $Click

var current_player: AudioStreamPlayer2D

func click_sound():
	current_player = click_player
	current_player.play()
