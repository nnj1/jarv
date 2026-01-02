extends Node3D

@export var player_scene: PackedScene = preload("res://scenes/player.tscn")

var typing_chat: bool = false

@onready var regex = RegEx.new()

func _ready():
	$CanvasLayer/role.text = GameManager.ROLE
	$CanvasLayer/id.text = str(get_tree().get_multiplayer().get_unique_id())
	
	# spawn the default map if the server:
	if multiplayer.is_server():
		change_map('town2')
		
	# if it's a client connecting, try to latch them into the spawn point on current map
	if not multiplayer.is_server():
		respawn(multiplayer.get_unique_id())
		
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
		
	if Input.is_action_just_released("command") and not typing_chat:
		get_node('CanvasLayer/chatbox/chatinput').text = '/'
		get_node('CanvasLayer/chatbox/chatinput').set_caret_column(1)
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
		send_chat.rpc(new_text, multiplayer.get_unique_id())
		get_node('CanvasLayer/chatbox/chatinput').text = ''
	get_node('CanvasLayer/chatbox/chatinput').release_focus()
	typing_chat = false
	
func _on_chathistory_ready() -> void:
	get_node('CanvasLayer/chatbox/chathistory').set_multiplayer_authority(1)

@rpc('any_peer', 'call_local','reliable')
func send_chat(new_text, id):
	# APPEND THE MESSAGE TO CHAT HISTORY
	var username = get_node('entities/'+ str(id)).username
	var color_hex = get_node('entities/'+ str(id)).skin_color.to_html(false)
	var bbcode_text = "\n[color=#" + color_hex + "]" + str(username) + "[/color]: " + new_text
	get_node('CanvasLayer/chatbox/chathistory').append_text(bbcode_text)
	$CanvasLayer/chatbox/AudioStreamPlayer.play()
	
	# commands anyone can do
	if new_text == '/respawn':
		var sender_id = multiplayer.get_remote_sender_id()
		respawn(sender_id)
	# commands only the server can do
	elif multiplayer.get_remote_sender_id() == 1:
		if new_text == '/customcommand':
			#get_node('entities/EnemyMultiplayerSpawner').spawn_new_enemy(Vector2(0,0))
			pass
		if new_text == '/snowon':
			get_node('entities/1').turn_snow_on()
		if new_text == '/snowoff':
			get_node('entities/1').turn_snow_off()
		if new_text == '/advancetrack':
			MusicPlayer.rpc('advance_track')
		if new_text == '/refuel':
			get_node('entities/Gmc').refuel()
		else:
			regex.compile("^/sethour\\s+(\\d+)$")
			var result = regex.search(new_text)
			if result:
				var hour_string = result.get_string(1) # Gets the first captured group (\d+)
				var hour_int = hour_string.to_int()
				$DirectionalLight3D.current_hour = hour_int
			else:
				# We use parentheses to capture the "THING"
				regex.compile("^/spawn\\s+(.+)")
				result = regex.search(new_text)
				if result:
					# get_string(0) is the whole match ("/spawn THING")
					# get_string(1) is the first captured group ("THING")
					var player_aim_ray = get_node('entities/1/camera_pivot/tps_arm/Camera3D/aim_ray')
					var local_point = player_aim_ray.target_position * 1
					var end_point = player_aim_ray.to_global(local_point)
					spawn_entity(result.get_string(1), end_point, randf_range(0.20, 1))
				
				else:
					# We use parentheses to capture the "THING"
					regex.compile("^/changemap\\s+(.+)")
					result = regex.search(new_text)
					if result:
						# get_string(0) is the whole match ("/changemap THING")
						# get_string(1) is the first captured group ("THING")
						change_map(result.get_string(1))

# for a player ID, grabs the player node and moves the player to the spawn point in the current map
# no need to RPC, as position is synced
func respawn(sender_id: int):
	# if you're a late joiner, wait until the map loads in and the spawn point is ready to join
	# TODO: could clean this up by using a signal
	var map_node_children = []
	while len(map_node_children) < 1:
		await get_tree().process_frame
		map_node_children = get_node('terrain').get_children()
	var player_spawn_point = null
	while player_spawn_point == null:
		await get_tree().process_frame
		player_spawn_point = get_node('terrain').get_children()[0].get_node_or_null('player_spawn_point')
	
	if player_spawn_point:
		get_node('entities/' + str(sender_id)).global_position = player_spawn_point.position

# spawns a new map, changes to it, and moves players and RV to the new spawn point
func change_map(name_of_scene: String):
	var scene = load('res://scenes/maps/' + name_of_scene + '.tscn')
	if scene:
		var scene_instance = scene.instantiate()
		for child in $terrain.get_children():
			child.queue_free()
		# move the player and RV to the map's ideal spawn point
		var player_spawn_point = scene_instance.get_node_or_null('player_spawn_point')
		var rv_spawn_point = scene_instance.get_node_or_null('rv_spawn_point')
		
		for entity in $entities.get_children():
			if 'IS_PLAYER' in entity:
				if player_spawn_point:
					entity.global_position = player_spawn_point.position
			elif 'IS_RV' in entity:
				if rv_spawn_point:
					global_teleport(entity, rv_spawn_point.position)
					#entity.global_position = rv_spawn_point.position # this breaks physics
			elif 'IS_ITEM_BODY' in entity:
				# delete the entity
				# TODO: HANDLE WHAT WILL HAPPEN IF PLAYER IS INTERACTING WITH ENTITY
				entity.smart_queue_free()
			elif 'IS_ENEMY' in entity:
				entity.queue_free()
				
		$terrain.add_child(scene_instance, true)

# Can spawn things like enemies, and ItemBody's
func spawn_entity(name_of_scene: String, origin_position: Vector3, given_scale: float = 1.0):
	var scene = load('res://scenes/entities/' + name_of_scene + '.tscn')
	if scene:
		var scene_instance = scene.instantiate()
		
		# if the scene is a skull, just give it a random color
		#TODO: THE INITIAL SETTINGS DON'T REPLICATE ON CLIENTS and this is janky fix
		if name_of_scene == 'skull':
			scene_instance.name = "skull_" + str(scene_instance.get_instance_id())
			get_node('entities').add_child(scene_instance, true)
			scene_instance.global_position = origin_position
			scene_instance.scale *= given_scale
			scene_instance.skin_color = Color.from_hsv(randf(), 1.0, 1.0) * 2
			
		# if it's an item_body, just the item
		elif name_of_scene in ['whiskey', 'soju', 'gas_carton'] :
			# TODO: Fix this class instantiation thing
			scene_instance.setup()
			# don't spawn this item at the end of the aim ray, it's too far! 
			# instead to go end of interaction ray
			var player_interact_ray = get_node('entities/1/camera_pivot/tps_arm/Camera3D/RayCast3D')
			var local_point = player_interact_ray.target_position * 1
			var end_point = player_interact_ray.to_global(local_point)
			scene_instance.position = end_point # once added it's local position will become global position
			get_node('entities').add_child(scene_instance, true)

func global_teleport(vehicle: VehicleBody3D, target_pos: Vector3):
	var rid = vehicle.get_rid()
	var new_transform = Transform3D(Basis.IDENTITY, target_pos)
	
	# Update the physics state directly
	PhysicsServer3D.body_set_state(rid, PhysicsServer3D.BODY_STATE_TRANSFORM, new_transform)
	
	# Critical: Reset velocity so the car doesn't keep its previous momentum
	PhysicsServer3D.body_set_state(rid, PhysicsServer3D.BODY_STATE_LINEAR_VELOCITY, Vector3.ZERO)
	PhysicsServer3D.body_set_state(rid, PhysicsServer3D.BODY_STATE_ANGULAR_VELOCITY, Vector3.ZERO)
