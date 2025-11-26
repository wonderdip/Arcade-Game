extends Control

signal character_changed(character, player_number)
var player_number = 1

var first_player_chose: bool = 0
var second_player_chose: bool = 0

@onready var p_1: Button = $Panel/VBoxContainer/HBoxContainer/P1

func _ready() -> void:
	p_1.grab_focus()
	
func _on_p_1_pressed() -> void:
	emit_signal("character_changed", "P1", player_number)
	print(player_number)
	player_number = 2
	
func _on_p_2_pressed() -> void:
	emit_signal("character_changed", "P2", player_number)
	player_number = 2
	
func _on_p_3_pressed() -> void:
	emit_signal("character_changed", "P3", player_number)
	player_number = 2
