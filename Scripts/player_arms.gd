extends Area2D

@onready var anim: AnimationPlayer = $AnimationPlayer
@onready var arm_sprite: Sprite2D = $ArmSprite
@onready var collision_shape: CollisionShape2D = $CollisionShape2D

var is_hitting: bool = false
var is_bumping: bool = false
var facing_right: bool = true  # Track which direction we're facing

@export var hit_force: float = 20.0
@export var upward_force: float = -20.0

@export var bump_force: float = 10.0
@export var bump_upward_force: float = -60.0  # bump should lift more than hit


func swing():
	if not is_hitting and not is_bumping:  # Don't hit while bumping
		is_hitting = true
		visible = true
		monitoring = true
		anim.play("Hit")
		

func bump():
	if not is_bumping and not is_hitting:  # Don't bump while hitting
		is_bumping = true
		visible = true
		monitoring = true
		anim.play("Bump")

func stop_bump():
	# Called when player releases bump button
	if is_bumping:
		is_bumping = false
		anim.stop()
		anim.play("RESET")  # Reset to default pose
		visible = false
		monitoring = false

func stop_hit():
	if is_hitting:
		is_hitting = false
		anim.stop()
		anim.play("RESET")
		visible = false
		monitoring = false
		
func _on_animation_player_animation_finished(anim_name: StringName) -> void:
	if anim_name == "Hit":
		is_hitting = false
		visible = false
		monitoring = false
	elif anim_name == "Bump":
		# Bump animation finished naturally (shouldn't happen since it loops)
		is_bumping = false
		visible = false
		monitoring = false

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("ball") and body is RigidBody2D:
		var direction = Vector2(1, 0)
		if not facing_right:
			direction = Vector2(-1, 0)
		
		if is_hitting:
			body.apply_impulse(direction * hit_force + Vector2(0, upward_force))
		elif is_bumping:
			body.apply_impulse(direction * bump_force + Vector2(0, bump_upward_force))

func sprite_direction(sprite_dir):
	var should_face_right = true
	
	# Determine which direction we should face
	if sprite_dir > 0:
		should_face_right = true
	elif sprite_dir < 0:
		should_face_right = false
	else:
		# If no input, keep current direction
		return
	
	# Only update if direction changed
	if should_face_right != facing_right:
		facing_right = should_face_right
		
		# Flip the entire node by inverting the scale
		# This flips both sprite and collision shape together
		scale.x = 1 if facing_right else -1
