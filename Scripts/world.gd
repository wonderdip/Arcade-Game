extends Node2D

@onready var player: CharacterBody2D = $Player
@onready var ball_scene: PackedScene = preload("res://Scenes/ball.tscn")

func _on_block_zone_body_entered(body: Node2D) -> void:
	if body == player:
		player.in_blockzone = true

func _on_block_zone_body_exited(body: Node2D) -> void:
	if body == player:
		player.in_blockzone = false

func _process(_delta: float) -> void:
	if Input.is_action_just_pressed("spawnball"):
		var ball_instance = ball_scene.instantiate()
		ball_instance.global_position = Vector2(80, -40)
		add_child(ball_instance)
