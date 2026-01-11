extends Node2D

# Reference the CanvasLayer child
@onready var menu_layer: CanvasLayer = $CanvasLayer 

func _ready():
	# Hide the menu on start
	menu_layer.hide()

func _input(event):
	if event.is_action_pressed("ui_cancel"):
		toggle_menu()
		
func toggle_menu():
	# play the toggle sound
	$AudioStreamPlayer2D.play()
	
	# Toggle visibility of the CanvasLayer
	menu_layer.visible = !menu_layer.visible
