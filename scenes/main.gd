extends Node

@export var default_names = [
  "SnowyBooty",
  "FrostyCheeks",
  "IcyBooty",
  "ChillyCheeks",
  "PowderBooty",
  "BlizzardCheeks",
  "ArcticBooty",
  "GlacierCheeks",
  "WinterBooty",
  "SlushyCheeks",
  "FlurryBooty",
  "FrozenCheeks",
  "BootyBlizzard",
  "CheeksOfIce",
  "TundraBooty",
  "SubZeroCheeks",
  "BootyAvalanche",
  "RosyCheeksWinter",
  "DriftBooty",
  "AlpineCheeks",
  "SleetBooty",
  "ShiverCheeks",
  "HailStoneBooty",
  "FrostbiteCheeks",
  "EvergreenBooty",
  "AmitArctic",
  "ReddyFrost",
  "Amit_On_Ice",
  "ReddyToSki",
  "AmitAvalanche",
  "ReddyForSnow",
  "SummitAmit",
  "Reddy_SubZero",
  "AmitAlps",
  "ReddyGlacier",
  "AmitBlizzard",
  "ReddyWinter",
  "AmitTheIceKing",
  "ReddyChill",
  "AmitSnowfall",
  "ReddyFreeze",
  "AmitColdSnap",
  "ReddyTundra",
  "AmitWhiteout",
  "ReddyIcicle",
  "AmitBooty",
  "ReddyCheeks",
  "AmitFrostyBooty",
  "ReddyIceCheeks",
  "Amit_Booty_Blizzard",
  "Reddy_Snowy_Cheeks",
  "AmitPowderCheeks",
  "ReddyArcticBooty",
  "AmitTheCheekySnowman",
  "ReddyBootyDrift"
]

func _ready() -> void:
	
	# preset default username
	$CanvasLayer/VBoxContainer/HBoxContainer2/TextEdit.text = default_names.pick_random()
	GameManager.selected_username = $CanvasLayer/VBoxContainer/HBoxContainer2/TextEdit.text
	
	# preset default skin color
	set_random_color($CanvasLayer/VBoxContainer/HBoxContainer2/ColorPickerButton)
	GameManager.selected_skin = $CanvasLayer/VBoxContainer/HBoxContainer2/ColorPickerButton.color
	
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

func _on_text_edit_text_changed(new_text:String) -> void:
	GameManager.selected_username = new_text

## Takes any ColorPicker or ColorPickerButton and assigns a random vibrant color
func set_random_color(picker_node: Control) -> void :
	if picker_node.has_method("set_pick_color") or "color" in picker_node:
		# Using HSV for a "cleaner" default color look
		var random_hue: float = randf()
		var saturation: float = 0.8
		var value: float = 0.9
		
		var new_color = Color.from_hsv(random_hue, saturation, value)
		picker_node.color = new_color
	else:
		push_error("The node passed to set_random_color does not have a color property.")
