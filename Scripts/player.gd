extends CharacterBody2D


@export var Speed = 200.0
@export var JumpHeight = -200.0
var is_jumping: bool = false
var can_jump: bool = true
@onready var animation_player: AnimatedSprite2D = $AnimationPlayer


func _physics_process(delta: float) -> void:
	# Add the gravity.
	if can_jump == false and is_on_floor():
		can_jump = true
	velocity += get_gravity() * delta
		
	# Handle jump.
	if Input.is_action_just_pressed("jump") and is_on_floor() and can_jump:
		velocity.y = JumpHeight
		animation_player.play("Jump")
		is_jumping = true

	# Get the input direction and handle the movement/deceleration.
	# As good practice, you should replace UI actions with custom gameplay actions.
	var direction := Input.get_axis("left", "right")
	if direction and !is_jumping:
		velocity.x = direction * Speed
		animation_player.play("Run")
	elif !is_jumping:
		velocity.x = move_toward(velocity.x, 0, Speed)
		animation_player.play("Idle")
		
	if direction > 0:
		animation_player.flip_h = false
	elif direction < 0:
		animation_player.flip_h = true
		
	move_and_slide()
