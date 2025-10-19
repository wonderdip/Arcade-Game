extends Node

@onready var click_player: AudioStreamPlayer2D = $Click

var sfx_vol: float = 50
var current_player: AudioStreamPlayer2D

func click_sound():
	current_player = click_player
	play_sfx()
	
func play_sfx():
	var normalized = sfx_vol / 100.0
	# Make the curve steeper so low volumes are much quieter
	normalized = pow(normalized, 2.5)
	current_player.volume_db = linear_to_db(normalized)
	print(current_player.volume_db)
	current_player.play()

	
func change_sfx_vol(volume):
	sfx_vol = volume
	current_player = click_player
	play_sfx()
