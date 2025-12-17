extends Control

@export var settings_visibilty: bool = true
@export var exit_visibility: bool = true
@onready var settings_button: Button = $"VBoxContainer/Settings button"
@onready var exit_button: Button = $VBoxContainer/Exit_Button

func _ready() -> void:
	settings_button.visible = settings_visibilty
	exit_button.visible = exit_visibility
