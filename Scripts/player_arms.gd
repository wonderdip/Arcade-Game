extends Area2D

@onready var anim: AnimationPlayer = $AnimationPlayer
@onready var arm_sprite: Sprite2D = $ArmSprite
@onready var collision_shape: CollisionShape2D = $CollisionShape2D

var is_hitting: bool = false
var is_bumping: bool = false
var is_blocking: bool = false
var is_setting: bool = false
var facing_right: bool = true
var hit_bodies: Dictionary = {}  # Tracks last hit time for each ball

@export var hit_force: float = 50.0
@export var downward_force: float = -20.0
@export var bump_force: float = 10.0
@export var bump_upward_force: float = -25.0
@export var set_force: float = 40
@export var set_upward_force: float = -40
@export var hit_cooldown: float = 0.2
@export var max_ball_speed: float = 400.0

func _ready():
	monitoring = true
	monitorable = true
	collision_shape.disabled = true
	
	# Connect signals safely using method references
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)
	
	if not body_exited.is_connected(_on_body_exited):
		body_exited.connect(_on_body_exited)

func swing():
	if not is_hitting and not is_bumping:
		is_hitting = true
		hit_bodies.clear()
		collision_shape.disabled = false
		visible = true
		anim.play("Hit")
	else:
		print("tried to hit weww")

func bump():
	if not is_bumping and not is_hitting and not is_blocking and not is_setting:
		is_bumping = true
		hit_bodies.clear()
		collision_shape.disabled = false
		visible = true
		anim.play("Bump") 

func block():
	if not is_hitting and not is_blocking:
		is_blocking = true
		hit_bodies.clear()
		collision_shape.disabled = false
		visible = true
		anim.play("Block")

func setting():
	if not is_setting and not is_bumping and not is_hitting and not is_blocking:
		is_setting = true
		hit_bodies.clear()
		collision_shape.disabled = false
		visible = true
		anim.play("Set")

func stop_setting():
	is_setting = false
	cleanup_anim()

func stop_hit():
	is_hitting = false
	cleanup_anim()

func stop_bump():
	is_bumping = false
	cleanup_anim()

func stop_block():
	is_blocking = false
	cleanup_anim()

func cleanup_anim():
	hit_bodies.clear()
	collision_shape.disabled = true
	anim.stop()
	anim.play("RESET")
	visible = false

# Called when a body enters the arm's area
func _on_body_entered(body: Node):
	if not (is_hitting or is_bumping or is_blocking or is_setting):
		return
	if not (body.is_in_group("ball") and body is RigidBody2D):
		return
	if not "scored" in body or body.scored:
		return

	var current_time = Time.get_ticks_msec() / 1000.0
	if body in hit_bodies and current_time - hit_bodies[body] < hit_cooldown:
		return

	# Ball must be above the arms
	if body.global_position.y > collision_shape.global_position.y + 3:
		return

	_apply_hit_to_ball(body)
	hit_bodies[body] = current_time

func _on_body_exited(body: Node):
	# Allow ball to be hit again after cooldown
	if body.is_in_group("ball") and body in hit_bodies:
		var current_time = Time.get_ticks_msec() / 1000.0
		hit_bodies[body] = current_time - hit_cooldown + 0.05

func _apply_hit_to_ball(body: RigidBody2D):
	var impulse: Vector2
	var hit_direction: Vector2
	var contact_point = collision_shape.global_position

	# Get current velocity before hit
	var ball_vel = body.linear_velocity

	# Optional: reduce or cancel downward velocity
	if ball_vel.y > 0:
		body.linear_velocity.y = ball_vel.y * 0.1  # or 0 for full reset

	if is_bumping:
		hit_direction = Vector2(0.2 if facing_right else -0.2, -1).normalized()
		impulse = hit_direction * bump_force + Vector2(0, bump_upward_force)
	elif is_hitting or is_blocking:
		hit_direction = Vector2(1 if facing_right else -1, -0.2).normalized()
		impulse = hit_direction * hit_force + Vector2(0, -downward_force)
	elif is_setting:
		hit_direction = Vector2(0.2 if facing_right else -0.2, -1).normalized()
		impulse = hit_direction * set_force + Vector2(0, set_upward_force)

	body.apply_impulse(impulse, contact_point - body.global_position)


	# Cap the speed
	await get_tree().process_frame
	if body.linear_velocity.length() > max_ball_speed:
		body.linear_velocity = body.linear_velocity.normalized() * max_ball_speed

func sprite_direction(sprite_dir: float):
	if sprite_dir > 0:
		if not facing_right:
			facing_right = true
			scale.x = 1
	elif sprite_dir < 0:
		if facing_right:
			facing_right = false
			scale.x = -1

func _on_animation_player_animation_finished(anim_name: StringName) -> void: 
	if anim_name == "Hit": 
		is_hitting = false 
		hit_bodies.clear() 
		collision_shape.disabled = true 
		visible = false 
		
	elif anim_name == "Block":
		is_blocking = false 
		hit_bodies.clear() 
		collision_shape.disabled = true 
		visible = false 
		
	elif anim_name == "Bump": # Don't clear when bump animation finishes if still holding button pas
		pass
		
	elif anim_name == "Set":
		pass
