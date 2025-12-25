extends Node3D

@export var player_scene: PackedScene = preload("res://scenes/player.tscn")

var typing_chat: bool = false

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

func _input(_event: InputEvent):
	if Input.is_action_just_released("chat"):
		get_node('CanvasLayer/chatbox/chatinput').grab_focus()
		typing_chat = true
		
# code for chat functionality
func _on_chatinput_focus_entered() -> void:
	# When TextEdit gains focus, disable player input handling
	typing_chat = true

func _on_chatinput_focus_exited() -> void:
	# When TextEdit loses focus, re-enable player input handling
	typing_chat = false

func _on_chatinput_text_submitted(new_text: String) -> void:
	if new_text != '':
		if not is_multiplayer_authority():
			send_chat.rpc_id(1, new_text, multiplayer.get_unique_id())
		else:
			send_chat(new_text, multiplayer.get_unique_id())
		get_node('CanvasLayer/chatbox/chatinput').text = ''
	get_node('CanvasLayer/chatbox/chatinput').release_focus()
	typing_chat = false
	
func _on_chathistory_ready() -> void:
	get_node('CanvasLayer/chatbox/chathistory').set_multiplayer_authority(1)

@rpc('any_peer', 'unreliable_ordered')
func send_chat(new_text, id):
	# APPEND THE MESSAGE TO CHAT HISTORY
	get_node('CanvasLayer/chatbox/chathistory').text += '\n' + str(id) + ':  ' + new_text
	# if the message contains a server code send it to server TODO: only allow the authority to do this!
	if multiplayer.is_server():
		if new_text == '/customcommand':
			#get_node('entities/EnemyMultiplayerSpawner').spawn_new_enemy(Vector2(0,0))
			pass
