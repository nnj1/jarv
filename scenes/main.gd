extends Node

func _ready() -> void:
	pass
	
func _on_host_pressed():
	GameManager.host_game()

func _on_join_pressed():
	GameManager.join_game($VBoxContainer/HBoxContainer/TextEdit.text, int($VBoxContainer/HBoxContainer/TextEdit2.text))
