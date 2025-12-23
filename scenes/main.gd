extends Node

func _ready() -> void:
	pass
	
func _on_host_pressed():
	GameManager.host_game()

func _on_join_pressed():
	GameManager.join_game($CanvasLayer/VBoxContainer/HBoxContainer/TextEdit.text, int($CanvasLayer/VBoxContainer/HBoxContainer/TextEdit2.text))
