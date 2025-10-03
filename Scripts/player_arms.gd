extends Area2D

@onready var anim: AnimationPlayer = $AnimationPlayer

var is_hitting: bool = false
@export var hit_force: float = 20.0
@export var upward_force: float = -20.0

func swing():
	if not is_hitting:
		is_hitting = true
		visible = true
		monitoring = true
		anim.play("Hit")

func _on_animation_player_animation_finished(anim_name: StringName) -> void:
	if anim_name == "Hit":
		is_hitting = false
		visible = false
		monitoring = false

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("ball"):  # make sure your ball is in a "ball" group
		if body is RigidBody2D:
			var direction = Vector2(1, 0)  # right hit, change if facing left
			if $"../Sprite".flip_h: # if player flipped left
				direction = Vector2(-1, 0)
			# Apply impulse (forward + upward)
			body.apply_impulse(direction * hit_force + Vector2(0, upward_force))
