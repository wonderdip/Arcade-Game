extends Area2D

func _ready():
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func _on_body_entered(body: Node2D):
	if body.is_in_group("ball") and body.has_method("enter_hover_zone"):
		body.enter_hover_zone()


func _on_body_exited(body: Node2D):
	if body.is_in_group("ball") and body.has_method("exit_hover_zone"):
		body.exit_hover_zone()
