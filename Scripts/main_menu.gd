extends Control


func _on_server_pressed() -> void:
	Networkhandler.start_server()


func _on_client_pressed() -> void:
	Networkhandler.start_client()
