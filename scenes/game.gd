extends Node3D

@export var player_scene: PackedScene = preload("res://scenes/player.tscn")

func _ready():
	$CanvasLayer/role.text = GameManager.ROLE
	$CanvasLayer/id.text = str(get_tree().get_multiplayer().get_unique_id())
		
func _process(_delta: float) -> void:
	# Get the FPS from the Engine singleton
	var fps = Engine.get_frames_per_second()
	
	# Update the label text
	# "FPS: %d" rounds the number to an integer
	$CanvasLayer/HBoxContainer/FPS.text = "FPS: %d" % fps
	
	# Optional: Change color based on performance
	if fps < 30:
		$CanvasLayer/HBoxContainer/FPS.add_theme_color_override("font_color", Color.RED)
	elif fps < 55:
		$CanvasLayer/HBoxContainer/FPS.add_theme_color_override("font_color", Color.YELLOW)
	else:
		$CanvasLayer/HBoxContainer/FPS.add_theme_color_override("font_color", Color.GREEN)

	# update the time display
	$CanvasLayer/HBoxContainer/time.text = $DirectionalLight3D.get_time_12h()
	
	# check for any broken math
	## Get every single node currently in the game tree
	#var all_nodes = get_tree().root.find_children("*", "Node3D", true, false)
	#
	#for node in all_nodes:
		#var t = node.global_transform
		#
		## Check if any part of the transform matrix is non-finite
		#if not (is_finite(t.origin.x) and is_finite(t.origin.y) and is_finite(t.origin.z) and \
				#is_finite(t.basis.x.x) and is_finite(t.basis.y.y) and is_finite(t.basis.z.z)):
			#
			#print_rich("[color=red][b]MATH EXPLOSION DETECTED![/b][/color]")
			#print_rich("Node Name: [color=yellow]", node.name, "[/color]")
			#print("Path: ", node.get_path())
			#print("Transform: ", t)
			#
			## Freeze the game so you can look at the Remote Scene Tree
			#get_tree().paused = true 
			#return
