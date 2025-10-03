extends Node2D

@onready var player: CharacterBody2D = $Player

func _on_block_zone_body_entered(body: Node2D) -> void:
	if body == player:
		player.in_blockzone = true


func _on_block_zone_body_exited(body: Node2D) -> void:
	if body == player:
		player.in_blockzone = false
