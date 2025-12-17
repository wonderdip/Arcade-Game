extends SpinBox

var can_step: bool = true
var step_timer: float = 0.0
const STEP_DELAY: float = 0.15  # Delay between steps in seconds

func _process(delta):
	if step_timer > 0:
		step_timer -= delta
		if step_timer <= 0:
			can_step = true
			
	if Input.is_action_just_pressed("exit_ui") and has_focus() and name == "FPS":
		$"../Vysnc".grab_focus()
	if Input.is_action_just_pressed("exit_ui") and has_focus() and name == "SpinBox":
		$"../HBoxContainer/Confirm".grab_focus()
		
func _input(event):
	if not has_focus():
		return
	
	# Only use is_action_pressed for initial press detection
	if can_step:
		if event.is_action_pressed("ui_up") and not event.is_echo():
			value += step
			can_step = false
			step_timer = STEP_DELAY
			get_viewport().set_input_as_handled()
		elif event.is_action_pressed("ui_down") and not event.is_echo():
			value -= step
			can_step = false
			step_timer = STEP_DELAY
			get_viewport().set_input_as_handled()

func _gui_input(event):
	# Prevent the LineEdit from taking focus on click
	if event is InputEventMouseButton and event.pressed:
		grab_focus()
		accept_event()
