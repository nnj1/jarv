extends Node

func _ready() -> void:
	pass
	
func _on_host_pressed():	
	GameManager.start_server(int($CanvasLayer/VBoxContainer/HBoxContainer/TextEdit2.text))
	#TODO: Get the scene transition to work without destroying multiplayer connectivity
	#SceneTransition.change_scene('res://scenes/game.tscn')
	get_tree().change_scene_to_file('res://scenes/game.tscn')

func _on_join_pressed():
	GameManager.start_client($CanvasLayer/VBoxContainer/HBoxContainer/TextEdit.text)
	#SceneTransition.change_scene('res://scenes/game.tscn')
	get_tree().change_scene_to_file('res://scenes/game.tscn')

func _on_color_picker_button_color_changed(color: Color) -> void:
	GameManager.selected_skin = color

func _on_text_edit_text_changed() -> void:
	GameManager.selected_username = $CanvasLayer/VBoxContainer/HBoxContainer2/TextEdit.text
