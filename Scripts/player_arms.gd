extends Area2D

@onready var anim: AnimationPlayer = $AnimationPlayer
@onready var arm_sprite: Sprite2D = $ArmSprite
@onready var collision_shape: CollisionShape2D = $CollisionShape2D

var is_hitting: bool = false
var is_bumping: bool = false
var facing_right: bool = true
var hit_bodies: Dictionary = {}  # Changed to Dictionary to track timestamps

@export var hit_force: float = 150.0
@export var downward_force: float = -100.0

@export var bump_force: float = 80.0
@export var bump_upward_force: float = -200.0

@export var hit_cooldown: float = 0.15  # Time before same ball can be hit again


func _ready():
	monitoring = true
	monitorable = true
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)
	if not body_exited.is_connected(_on_body_exited):
		body_exited.connect(_on_body_exited)
	
	# Start with collision disabled
	collision_shape.disabled = true


func _physics_process(_delta):
	if not (is_hitting or is_bumping):
		return

	var current_time = Time.get_ticks_msec() / 1000.0
	var overlapping = get_overlapping_bodies()
	for body in overlapping:
		if not body.is_in_group("ball"):
			continue
		if body in hit_bodies and current_time - hit_bodies[body] < hit_cooldown:
			continue
		if body.global_position.y > collision_shape.global_position.y + 5:
			continue
		
		_apply_hit_to_ball(body)


func swing():
	if not is_hitting and not is_bumping:
		is_hitting = true
		hit_bodies.clear()
		visible = true
		collision_shape.disabled = false
		anim.play("Hit")


func bump():
	if not is_bumping and not is_hitting:
		is_bumping = true
		hit_bodies.clear()
		visible = true
		collision_shape.disabled = false
		anim.play("Bump")

	
func stop_bump():
	if is_bumping:
		is_bumping = false
		hit_bodies.clear()
		collision_shape.disabled = true
		anim.stop()
		anim.play("RESET")
		visible = false


func stop_hit():
	if is_hitting:
		is_hitting = false
		hit_bodies.clear()
		collision_shape.disabled = true
		anim.stop()
		anim.play("RESET")
		visible = false

		
func _on_animation_player_animation_finished(anim_name: StringName) -> void:
	if anim_name == "Hit":
		is_hitting = false
		hit_bodies.clear()
		collision_shape.disabled = true
		visible = false
	elif anim_name == "Bump":
		# Don't clear when bump animation finishes if still holding button
		pass


func _on_body_entered(body: Node2D) -> void:
	if not (is_hitting or is_bumping):
		return
	if not (body.is_in_group("ball") and body is RigidBody2D):
		return
	if body in hit_bodies:
		return
	
	# Ignore balls below the arms
	if body.global_position.y > collision_shape.global_position.y + 1:
		print("Invalid hit - ball below arms")
		return
	
	_apply_hit_to_ball(body)


func _on_body_exited(body: Node2D) -> void:
	# When ball leaves the area, allow it to be hit again after cooldown
	if body.is_in_group("ball") and body in hit_bodies:
		# Reset the timestamp so it can be hit again soon
		hit_bodies[body] = Time.get_ticks_msec() / 1000.0 - hit_cooldown + 0.05


func _apply_hit_to_ball(body: RigidBody2D) -> void:
	if body in hit_bodies:
		return
	
	# Record this hit with current timestamp
	hit_bodies[body] = Time.get_ticks_msec() / 1000.0
	
	var contact_point = collision_shape.global_position
	var hit_direction: Vector2
	
	if is_bumping:
		hit_direction = Vector2(0.2 if facing_right else -0.2, -1).normalized()
		var impulse = hit_direction * bump_force + Vector2(0, bump_upward_force)
		body.apply_impulse(impulse, contact_point - body.global_position)
		print("BUMP! Impulse:", impulse)
	elif is_hitting:
		hit_direction = Vector2(1 if facing_right else -1, -0.2).normalized()
		var impulse = hit_direction * hit_force + Vector2(0, -downward_force)
		body.apply_impulse(impulse, contact_point - body.global_position)
		print("HIT! Impulse:", impulse)


func sprite_direction(sprite_dir):
	if sprite_dir > 0:
		if not facing_right:
			facing_right = true
			scale.x = 1
	elif sprite_dir < 0:
		if facing_right:
			facing_right = false
			scale.x = -1
