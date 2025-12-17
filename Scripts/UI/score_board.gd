extends Node2D

@onready var player_one_sprite: Sprite2D = $PlayerOneScore
@onready var player_two_sprite: Sprite2D = $PlayerTwoScore

var player_two_score: int = 0
var player_one_score: int = 0
@export var last_point = 0

func _ready() -> void:
	player_one_sprite.frame = 0
	player_two_sprite.frame = 0
	last_point = 1

func update_score(player):
	if player == 1:
		player_two_score = (player_two_score + 1) % 10
		player_two_sprite.frame = player_two_score
		last_point = 2
	elif player == 2:
		player_one_score = (player_one_score + 1) % 10
		player_one_sprite.frame = player_one_score
		last_point = 1
