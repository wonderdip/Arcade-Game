extends Area2D

@onready var anim: AnimationPlayer = $AnimationPlayer
@onready var arm_sprite: Sprite2D = $ArmSprite
@onready var collision_shape: CollisionShape2D = $CollisionShape2D

var is_hitting: bool = false
var is_bumping: bool = false
var facing_right: bool = true  # Track which direction we're facing
var hit_bodies: Array = []  # Track bodies we've already hit this swing

@export var hit_force: float = 20.0
@export var upward_force: float = -20.0

@export var bump_force: float = 10.0
@export var bump_upward_force: float = -60.0  # bump should lift more than hit


func _ready():
	# Make sure monitoring is enabled from the start
	monitoring = true
	monitorable = true
	# Connect to body entered if not already connected in scene
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)


func swing():
	if not is_hitting and not is_bumping:  # Don't hit while bumping
		is_hitting = true
		hit_bodies.clear()  # Reset hit tracking
		visible = true
		# Monitoring should already be true from _ready
		anim.play("Hit")
		

func bump():
	if not is_bumping and not is_hitting:  # Don't bump while hitting
		is_bumping = true
		hit_bodies.clear()  # Reset hit tracking
		visible = true
		# Monitoring should already be true from _ready
		anim.play("Bump")

func stop_bump():
	# Called when player releases bump button
	if is_bumping:
		is_bumping = false
		hit_bodies.clear()
		anim.stop()
		anim.play("RESET")  # Reset to default pose
		visible = false

func stop_hit():
	if is_hitting:
		is_hitting = false
		hit_bodies.clear()
		anim.stop()
		anim.play("RESET")
		visible = false
		
func _on_animation_player_animation_finished(anim_name: StringName) -> void:
	if anim_name == "Hit":
		is_hitting = false
		hit_bodies.clear()
		visible = false
	elif anim_name == "Bump":
		# Bump animation finished naturally (shouldn't happen since it loops)
		is_bumping = false
		hit_bodies.clear()
		visible = false

func _on_body_entered(body: Node2D) -> void:
	# Only process if we're actually swinging/bumping and haven't hit this body yet
	if not (is_hitting or is_bumping):
		return
		
	if body.is_in_group("ball") and body is RigidBody2D:
		# Prevent hitting the same ball multiple times in one swing
		if body in hit_bodies:
			return
		
		hit_bodies.append(body)
		
		var direction = Vector2(1, 0)
		if not facing_right:
			direction = Vector2(-1, 0)
		
		if is_hitting:
			var impulse = direction * hit_force + Vector2(0, upward_force)
			body.apply_impulse(impulse)
			print("Hit! Impulse: ", impulse)  # Debug
		elif is_bumping:
			var impulse = direction * bump_force + Vector2(0, bump_upward_force)
			body.apply_impulse(impulse)
			print("Bump! Impulse: ", impulse)  # Debug

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
