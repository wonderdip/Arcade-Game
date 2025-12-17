extends Control

@onready var server_name: LineEdit = $VBoxContainer/ServerName
@onready var player_number: SpinBox = $VBoxContainer/SpinBox

func _ready() -> void:
	server_name.grab_focus()
	_setup_spinbox_controller_input(player_number)
	
func _on_confirm_pressed() -> void:
	if server_name.text.strip_edges().length() == 0:
		name = "Unnamed Server"
	else:
		name = server_name.text
	Networkhandler.is_local = false
	Networkhandler.is_solo = false
	Networkhandler.start_server(name)

func _on_spin_box_value_changed(value: int) -> void:
	Networkhandler.MAX_CLIENTS = value


func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://Scenes/Menus/title_screen.tscn")
	
func _get_spinbox_line_edit(spinbox: SpinBox) -> LineEdit:
	# SpinBox has a LineEdit child that handles the actual input
	for child in spinbox.get_children():
		if child is LineEdit:
			return child
	return null

func _setup_spinbox_controller_input(spinbox: SpinBox):
	# Disable the internal LineEdit to prevent it from capturing focus
	var line_edit = _get_spinbox_line_edit(spinbox)
	if line_edit:
		line_edit.focus_mode = Control.FOCUS_NONE
		line_edit.mouse_filter = Control.MOUSE_FILTER_PASS
	
	# Make sure SpinBox itself can receive focus
	spinbox.focus_mode = Control.FOCUS_ALL
	
	# Connect to focus events to ensure proper behavior
	if not spinbox.focus_entered.is_connected(_on_player_number_focus_entered):
		spinbox.focus_entered.connect(_on_player_number_focus_entered)

func _on_player_number_focus_entered():
	# Ensure the SpinBox keeps focus and doesn't pass it to LineEdit
	player_number.grab_focus()
