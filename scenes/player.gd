extends CharacterBody3D

@onready var main_game_node = get_tree().get_root().get_node('Node3D')
@onready var interaction_ray_target_label = main_game_node.get_node('CanvasLayer/HBoxContainer/target')
@onready var interact_message_label = main_game_node.get_node('CanvasLayer/interact_message')
# --- Exported Variables ---
@export var speed: float = 10
@export var jump_velocity: float = 9
@export var mouse_sensitivity: float = 0.002
@export var camera_pivot: Node3D        # Drag the Camera Pivot (Node3D) here
@export var tps_arm: SpringArm3D       # Drag the TPS_Arm (SpringArm3D) here
@export var tps_pitch: float = 0.0
@export var fp_position: Node3D        # Drag the FP_Pos (Node3D) here
@export var transition_speed: float = 10.0 # How fast the camera moves when switching
@export var tps_distance: float = 4.0   # The maximum length of the SpringArm in TP mode

# --- New Exported Variables for Quake Movement ---
@export var friction: float = 6.0
@export var acceleration: float = 10.0
@export var air_acceleration: float = 2.0
@export var stop_speed: float = 1.0

@export var zoom_fov: float = 37.5 # Half of the default 75.0
@export var default_fov: float = 75.0
@export var zoom_speed: float = 8.0

var is_zooming: bool = false
@export var is_driving: bool = false
@export var seat_node: Node3D = null

# --- Constants ---
const CLAMP_ANGLE: float = 1.2
const GRAVITY: float = 9.8
const FOV_KICK: bool = true
const IS_PLAYER: bool = true

# --- State Variables ---
var is_first_person: bool = true
var camera: Camera3D
@onready var aim_ray: RayCast3D = $camera_pivot/tps_arm/Camera3D/aim_ray
@onready var interaction_ray: RayCast3D = $camera_pivot/tps_arm/Camera3D/RayCast3D
var weapon_index:int = 1
var max_weapons:int = 3
@export var max_health = 100
@export var current_health = 100
var health_decay_rate:float = 0.5
var recoil_velocity: Vector3 = Vector3.ZERO

# for damage values showing when player is attacked
@onready var damage_marker = preload('res://scenes/damage_marker.tscn')
@onready var damage_marker_point = $damage_marker_point

@onready var frost_material = main_game_node.get_node('CanvasLayer2/frozen').material
var frost_rate: float = 0.001 # 0.1 for debugging

# stuff for edit mode in the RV
var in_edit_mode:bool =  false
var in_rv: bool = false
var currently_highlighted_mesh: MeshInstance3D

var gravity_on:bool = true

@export var skin_color = Color(1,0,0)
@export var username:String = 'something'

@export var snow_status:bool = true

# Variables the GMC will hook into for driving purposes
@export var steer_input = 0.0
@export var forward_input = 0.0
@export var back_input = 0.0

# some stuff the host server sends the client when they spawn
var host_server_data: Dictionary

var weapons = [
	{
		'name': 'hand',
		'reticle': 0,
		'class':'MELEE'
	},
	{
		'name': 'grenadelauncher',
		'reticle': 82,
		'recoil_force':20,
		'class':'SINGLE',
		'projectile_scene': preload('res://scenes/entities/rocket.tscn')
	},
	{
		'name': 'knife',
		'reticle': 45,
		'class':'MELEE'
	},
	{
		'name': 'mauser',
		'reticle': 37,
		'recoil_force':5,
		'class':'BURST'
	}
]

var entity_held = null

@rpc("any_peer",'call_local', 'reliable')
func set_skin_color(given_skin_color: Color):
	skin_color = given_skin_color# set the skin
	var mesh_instance = self.get_node('gnome_model/Sketchfab_model/Collada visual scene group/gnome_low/defaultMaterial')
	var base_mat = mesh_instance.get_active_material(0)
	base_mat = base_mat.duplicate()
	mesh_instance.set_surface_override_material(0, base_mat)
	#base_mat.next_pass = base_mat.next_pass.duplicate()
	base_mat.set_shader_parameter("blue_replacement_color", skin_color)

func change_weapon(index:  int = weapon_index):
	# turn off any interaction messages
	interact_message_label.visible = false
	# drop any held items
	if entity_held:
		entity_held.drop()
		self.entity_held = null
	for child in $weapons.get_children():
		child.visible = false
		# stop any running animations
		var player = child.get_node_or_null('AnimationPlayer')
		if player:
			player.stop()
	$weapons.get_children()[index].visible = true
	main_game_node.get_node('CanvasLayer/crosshair').texture = GlobalVars.get_cursor_texture(weapons[index].reticle, 20, 10)	
	$weaponswapSound.play()
	
func start_driving(_given_seat_node):
	# 1. Set local state so the Client enters the loop immediately
	self.is_driving = true
	# turn off collisions with internal items of the car 
	interaction_ray.set_collision_mask_value(6, false)
	
	# show the driving instructions
	main_game_node.get_node('CanvasLayer/RV_HUD/RV_INSTRUCTIONS').show()
	
	# 2. Assign the seat node locally so the position lock works
	self.seat_node = main_game_node.get_node('entities/Gmc/drivers_seat')
	
	# 3. Tell the server to register us (Host logic)
	rpc_id(1, "server_register_driver", true)
	
	# disable the player's main collision shape
	$CollisionShape3D.disabled = true
	
	# put away weapons when driving
	weapon_index = 0
	change_weapon(weapon_index)
	
func stop_driving():
	rpc_id(1, "server_register_driver", false)
	self.is_driving = false
	
	# turn back on collision with internal items in car
	interaction_ray.set_collision_mask_value(6, true)
	
	main_game_node.get_node('CanvasLayer/RV_HUD/RV_INSTRUCTIONS').hide()
	self.seat_node = null
	self.rotation = Vector3.ZERO
	$CollisionShape3D.disabled = false

@rpc('any_peer','call_local','reliable')
func move_to_position_and_rotation(given_position, given_basis) -> void:
	self.global_position = given_position
	self.global_transform.basis = given_basis
	
@rpc("any_peer", "call_local", "reliable")
func server_register_driver(starting: bool):
	if multiplayer.is_server():
		var gmc = main_game_node.get_node('entities/Gmc')
		if starting:
			gmc.driver_player_id = str(multiplayer.get_remote_sender_id())
		else:
			gmc.driver_player_id = ""

func decay_health(delta):
	if current_health > 0:
		# 
		# delta ensures the decay is consistent regardless of frame rate
		current_health -= health_decay_rate * delta
		
		# Prevent health from going below zero
		current_health = max(current_health, 0)
		
		
@rpc("any_peer", "call_local", "reliable")
func show_damage_marker(amount: int):
	var marker = damage_marker.instantiate()
	marker.prepare(amount)
	damage_marker_point.add_child(marker)
	
# Should be called by any client on all peers, but only the server will execute
# current_health sync from authority to peers via multiplayer synchronizer
@rpc("any_peer", "call_local", "reliable")
func damage(amount: int = 1):
	rpc('show_damage_marker', amount)
	# delta ensures the decay is consistent regardless of frame rate
	current_health -= amount
	
	if not $hurtSound.playing:
		$hurtSound.play()
	
	# Prevent health from going below zero
	current_health = max(current_health, 0)

func heal(amount: float = 1000) -> void:
	current_health = clamp(current_health + amount, 0, max_health)
		
func defrost():
	var tween = create_tween()
	#tween.set_trans(Tween.TRANS_EXPO)
	#tween.set_ease(Tween.EASE_IN)
	
	# Melt the ice back to 0
	tween.tween_property(frost_material, "shader_parameter/frost_amount", 0.0, 10)

func _enter_tree() -> void:
	set_multiplayer_authority(name.to_int())
	
@rpc("any_peer","call_remote","reliable")
func on_new_player(player_id: int) -> void:
	# if the new player who joins is not yourself, turn off the GPU particles
	var player_node = main_game_node.get_node('entities/' + str(player_id))
	if player_id != multiplayer.get_unique_id():
		player_node.get_node('GPUParticles3D').hide()

func _ready():
	
	if not is_multiplayer_authority():
		# if not the authority, make the guns visible on layer 1 and not layer 2
		# this allows you to see other players holding guns
		for weapon_mesh in GlobalVars.get_all_nested_meshes($weapons):
			weapon_mesh.set_layer_mask_value(1, true)
			weapon_mesh.set_layer_mask_value(2, false)
			# Deferred version:
			#weapon_mesh.call_deferred("set_layer_mask_value", 1, true)
			#print(weapon_mesh)
	
	if is_multiplayer_authority(): #and DisplayServer.window_is_focused():
		
		# get rid of frost on screen
		main_game_node.get_node('CanvasLayer2/frozen').material.set_shader_parameter('frost_amount', 0.0)
		
		# Lock the mouse at start
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		
		# set a crosshair
		main_game_node.get_node('CanvasLayer/crosshair').texture = GlobalVars.get_cursor_texture(weapon_index, 20, 10)
		
		# set default weapon (may change crosshair)
		change_weapon()
		
		# Get camera reference and set initial view
		camera = tps_arm.get_child(0) as Camera3D
		camera.make_current()
		
		_set_view_position(fp_position.global_position)
		tps_arm.spring_length = 0.00 # Start SpringArm collapsed for FP
		
		# set the particles to the snow status of the server player
		if main_game_node.get_node('entities/1'):
			snow_status = main_game_node.get_node('entities/1').snow_status
			$GPUParticles3D.emitting = snow_status
			
		# Joined game message
		main_game_node.rpc('send_chat', 'Just joined the game!', multiplayer.get_unique_id())
		
		# DO NOT RENDER THE EXISTING PLAYER'S GPU PARTICLES, if you're not the server
		for child in main_game_node.get_node('entities').get_children():
			if 'IS_PLAYER' in child:
				if child.IS_PLAYER:
					if child.name != self.name:
						child.get_node('GPUParticles3D').hide()
			
		# call the function that lets other players turn off GPU effects
		rpc('on_new_player', self.multiplayer.get_unique_id())
		
		# set up the timer for occasional grunting sounds 
		$idleSound/Timer.start()
		$idleSound/Timer.timeout.connect(_on_grunt_timer_timeout)
		
	else:
		camera = tps_arm.get_child(0) as Camera3D
		camera.current = false
		$CanvasLayer.hide()
		$CanvasLayer/SubViewportContainer/SubViewport/Camera3D.current = false	
	
	
@rpc("any_peer","call_local","reliable")
func network_lock_self_to_driver_seat(delta):
	# lock position client side 
	var target_position = main_game_node.get_node('entities/Gmc/drivers_seat/driver_position').global_position
	self.global_position = target_position
	#print('position locked')
	
	# smooth rotation
	var target_quat = main_game_node.get_node('entities/Gmc/drivers_seat/driver_position').global_transform.basis.get_rotation_quaternion()
	var current_quat = self.global_transform.basis.get_rotation_quaternion()
	
	# SAFETY CHECK 1: Ensure quaternions are valid and not identical
	if current_quat.is_finite() and target_quat.is_finite():
		# Only slerp if there is actually a difference to calculate
		if not current_quat.is_equal_approx(target_quat):
			var final_quat = current_quat.slerp(target_quat, 5 * delta)
			
			# SAFETY CHECK 2: Final validation before applying to the GPU
			if final_quat.is_finite():
				# Apply rotation while preserving current scale
				var s = global_basis.get_scale()
				if s.is_finite():
					self.global_transform.basis = Basis(final_quat).scaled(s)	


func lock_self_to_driver_seat(delta):
	# lock position client side (may also do this server side to prevent jittering
	self.global_position = seat_node.get_node('driver_position').global_position
	#print('position locked')
	
	# smooth rotation
	var target_quat = seat_node.get_node('driver_position').global_transform.basis.get_rotation_quaternion()
	var current_quat = self.global_transform.basis.get_rotation_quaternion()
	
	# SAFETY CHECK 1: Ensure quaternions are valid and not identical
	if current_quat.is_finite() and target_quat.is_finite():
		# Only slerp if there is actually a difference to calculate
		if not current_quat.is_equal_approx(target_quat):
			var final_quat = current_quat.slerp(target_quat, 5 * delta)
			
			# SAFETY CHECK 2: Final validation before applying to the GPU
			if final_quat.is_finite():
				# Apply rotation while preserving current scale
				var s = global_basis.get_scale()
				if s.is_finite():
					global_transform.basis = Basis(final_quat).scaled(s)	

# 1. Physics Movement and Camera Interpolation
func _physics_process(delta):
	
	# decay health if outside the RV
	if not in_rv:
		decay_health(delta)
		# slowly grow the frost shader
		var current_frost = frost_material.get_shader_parameter('frost_amount')
		frost_material.set_shader_parameter('frost_amount', current_frost + delta * frost_rate)
	
	if not is_multiplayer_authority(): return
	
	# code for dropping held items
	if Input.is_action_just_pressed('interact') and entity_held and not main_game_node.typing_chat:
		entity_held.drop()
		self.entity_held = null
	
	# for checking interaction ray colliders
	if interaction_ray.is_colliding():
		var target = interaction_ray.get_collider()
		
		# put the target node name that is being collided with in the top right corner
		interaction_ray_target_label.text = str(target)
		
		# if this node has children that are meshes, change the highlight on the mesh if we are in edit mode
		# only do this if in RV
		if in_edit_mode:
					
			var closest_mesh = get_closest_mesh_to_raycast(interaction_ray)
			if closest_mesh:
				#print("Precisely hit: ", closest_mesh.name)
				# dehighlight any previously selected mesh
				if currently_highlighted_mesh != closest_mesh and currently_highlighted_mesh != null:
					set_highlight_mesh(currently_highlighted_mesh, false)
				# highlight the new mesh and set it as currently highlighted
				set_highlight_mesh(closest_mesh, true)
				currently_highlighted_mesh = closest_mesh	
		
		if 'is_interactable' in target and entity_held == null:
			if target.is_interactable and not 'IS_RV' in target:
				var message = target.custom_interact_message if ('custom_interact_message' in target) else 'Press E to interact'
				# show the interaction message if the target isn't pickable
				if not target.is_pickable:
					interact_message_label.text = message
					interact_message_label.visible = true
				# show the interaction message only if the hand is active when the target is pickable
				elif target.is_pickable:
					if weapons[weapon_index].name == 'hand':
						interact_message_label.text = message
						interact_message_label.visible = true
				
				# do the actual interaction if the player presses the key
				if Input.is_action_just_pressed('interact') and not main_game_node.typing_chat:
					target.interact(self)
	else:
		# reset to default message
		interact_message_label.text = 'Press E to interact'
		interact_message_label.visible = false
		
	# --- MOVEMENT (Same as original) ---
	if not is_driving:
		# 1. Handle Gravity
		if not is_on_floor() and gravity_on:
			velocity.y -= GRAVITY * delta

		# 2. Handle Jump (Standard Quake doesn't have jump cooldown)
		if is_on_floor() and Input.is_action_pressed("jump") and not main_game_node.typing_chat and not main_game_node.in_context_menu:
			velocity.y = jump_velocity
			rpc('play_jump_sound')

		# 3. Get Input Direction
		var input_dir = Vector3.ZERO
		if not main_game_node.typing_chat and not main_game_node.in_context_menu:
			input_dir = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
		var wish_dir = Vector3.ZERO
		if input_dir.length() > 0:
			wish_dir = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
			
		# 4. Apply Quake Physics
		if is_on_floor():
			velocity = ground_move(delta, wish_dir, velocity)
			if input_dir:
				# TODO: make this dependent on the surface you are walking on
				if not $moveSound.playing:
					$moveSound.play()
		else:
			velocity = air_move(delta, wish_dir, velocity)
		
		# Prevent the player from teleporting to the shadow dimension
		if not velocity.is_finite():
			velocity = Vector3.ZERO
		
		# dont allow shooting if pause menu is open (makes it annoying to use menu)
		if not PauseMenu.menu_layer.visible:
			# attack animation for all kinds of wdeapons
			# BURST CLASS: this means the weapon that is currently equipped is hitscan
			if weapons[weapon_index].class == 'BURST':
				if 'recoil_force' in weapons[weapon_index].keys():
					var weapon_animation_player = get_node_or_null('weapons/' + weapons[weapon_index].name + '/AnimationPlayer')
					if Input.is_action_pressed('shoot'):
						# play the shoot animation for the respective weapon
						if weapon_animation_player:
							if not weapon_animation_player.is_playing():
								weapon_animation_player.play('attack')
							# play the crosshair animation
							if not main_game_node.get_node('CanvasLayer/crosshair/AnimationPlayer').is_playing():
								main_game_node.get_node('CanvasLayer/crosshair/AnimationPlayer').play('bounce')	
						# add some physical player recoil
						var push_direction = global_transform.basis.z 
						var force = weapons[weapon_index].recoil_force
						recoil_velocity = push_direction * force / 10 # scale force down by factor of 10
						velocity += recoil_velocity
						#recoil_velocity = recoil_velocity.lerp(Vector3.ZERO, 10.0 * delta)
					
					if Input.is_action_just_released('shoot'):
						if weapon_animation_player:
							if weapon_animation_player.is_playing():
								weapon_animation_player.stop()
			
			elif weapons[weapon_index].class == 'SINGLE': # this class of weapons spawns projectiles
				if 'recoil_force' in weapons[weapon_index].keys():
					var weapon_animation_player = get_node_or_null('weapons/' + weapons[weapon_index].name + '/AnimationPlayer')
					if Input.is_action_pressed('shoot'):
						# play the shoot animation for the respective weapon
						if weapon_animation_player:
							if not weapon_animation_player.is_playing():
								weapon_animation_player.play('attack')
								# play the crosshair animation
								main_game_node.get_node('CanvasLayer/crosshair/AnimationPlayer').play('bounce')	
								
								# add some physical player recoil
								var push_direction = global_transform.basis.z 
								var force = weapons[weapon_index].recoil_force
								recoil_velocity = push_direction * force / 10 # scale force down by factor of 10
								velocity += recoil_velocity
								recoil_velocity = recoil_velocity.lerp(Vector3.ZERO, 10.0 * delta)
			
			elif weapons[weapon_index].class == 'MELEE':
					var weapon_animation_player = get_node_or_null('weapons/' + weapons[weapon_index].name + '/AnimationPlayer')
					if weapon_animation_player:
						if Input.is_action_pressed('shoot'):
							# play the shoot animation for the respective weapon
							if weapon_animation_player:
								if not weapon_animation_player.is_playing():
									weapon_animation_player.play('attack')
						
		# finally, we can move and slide (we are not driving the RV in this case)
		move_and_slide()
		
	elif seat_node and is_driving:
		
		# in driving mode
		self.steer_input = Input.get_action_strength("move_left") - Input.get_action_strength("move_right")
		self.forward_input = Input.get_action_strength("move_forward")
		self.back_input = Input.get_action_strength("move_back") 

		if Input.is_action_just_pressed('shift_gear'):
			seat_node.get_parent().rpc('network_gear_change')
		
		if Input.is_action_pressed('handbrake'):
			seat_node.get_parent().rpc('network_handbrake_on')
		
		if Input.is_action_just_released('handbrake'):
			seat_node.get_parent().rpc('network_handbrake_off')
		
		if Input.is_action_pressed("horn"):
			seat_node.get_parent().rpc('network_horn_on')
			
		if Input.is_action_just_released("horn"):
			seat_node.get_parent().rpc('network_horn_off')
		
		if Input.is_action_just_pressed('highbeams'):
			seat_node.get_parent().rpc('network_highbeams')
			
		# called on client side but using client's delta (aka client's physics)
		#lock_self_to_driver_seat(delta)
		#self.rpc('network_lock_self_to_driver_seat', delta)
		
	# --- CAMERA INTERPOLATION (New for smooth switching) ---
	var target_position: Vector3
	if is_first_person:
		target_position = fp_position.global_position
	else:
		# Target the SpringArm's global position when extended
		target_position = tps_arm.global_position
	
	# Inside _physics_process
	if camera and target_position.is_finite():
		# Clamp weight between 0 and 1 to prevent overshoot/NaN
		var weight = clamp(delta * transition_speed, 0.0, 1.0)
		camera.global_position = camera.global_position.lerp(target_position, weight)
		
		# Final safety: If the camera still breaks, snap it to target
		if not camera.global_position.is_finite():
			camera.global_position = target_position
		
	# make all weapons point in same direction camera is looking at
	$weapons.look_at(camera.global_position - camera.global_basis.z * 100.0)
	
	
	if camera:
		# Determine which FOV to aim for
		var target_fov = zoom_fov if is_zooming else default_fov
		# Interpolate the camera's FOV
		camera.fov = lerp(camera.fov, target_fov, delta * zoom_speed)
		
	# Inside _physics_process
	if FOV_KICK and camera:
		var horizontal_speed = Vector3(velocity.x, 0, velocity.z).length()
		var target_fov = zoom_fov if is_zooming else (default_fov + (horizontal_speed * 0.5))
		camera.fov = lerp(camera.fov, target_fov, delta * 8.0)
		
	# Check if velocity has exploded
	if not velocity.is_finite():
		print("VELOCITY ERROR: ", velocity)
		breakpoint # This pauses the game so you can look at variables

	# Check if the camera has exploded
	if camera and not camera.global_position.is_finite():
		print("CAMERA ERROR: ", camera.global_position)
		breakpoint

# 2. Input Handling (Mouse Look and Toggles)
func _unhandled_input(event):
	
	if not is_multiplayer_authority(): return
	
	# Only process input if the window is currently focused
	if not DisplayServer.window_is_focused():
		return
		
	# Detect Zoom Input
	if event.is_action_pressed("zoom"): # Map this to Right Mouse Button
		is_zooming = true
		main_game_node.get_node('CanvasLayer/crosshair/AnimationPlayer').play('spin_in')
	elif event.is_action_released("zoom"):
		is_zooming = false
		main_game_node.get_node('CanvasLayer/crosshair/AnimationPlayer').play('spin_in')
		
	# Detect Edit mode Input
	if event.is_action_pressed("edit") and not is_driving: # Map this to Right Mouse Button
		in_edit_mode = true
		main_game_node.get_node('CanvasLayer/edit_mode_display').show()
		# play the sound
		$editSound.play()
		# boost the FOV
		#default_fov = 100
		# swap to the hand
		weapon_index = 0
		change_weapon(weapon_index)
		# change crosshair texture
		main_game_node.get_node('CanvasLayer/crosshair').texture = GlobalVars.get_cursor_texture(116, 20, 10)	
	elif event.is_action_released("edit") and not is_driving:
		in_edit_mode = false
		main_game_node.get_node('CanvasLayer/edit_mode_display').hide()
		# turn off any currently highlighted mesh
		if currently_highlighted_mesh:
			set_highlight_mesh(currently_highlighted_mesh, false)
		currently_highlighted_mesh = null
		#$editSound.play()
		default_fov = 75
		# swap to the hand
		weapon_index = 0
		change_weapon(weapon_index)
		
	if event.is_action_pressed("shift_click") and not is_driving:	
		var thing = interaction_ray.get_collider()
		if thing:
			var menu_scene = preload('res://scenes/context_menu.tscn')
			var menu_instance = menu_scene.instantiate()
			if currently_highlighted_mesh:	
				print('Shift clicked on ' + str(currently_highlighted_mesh))
				menu_instance.prepare(thing.name, 'An item description would go here', thing, currently_highlighted_mesh)
			else:
				menu_instance.prepare(thing.name, 'An item description would go here. This item doesn\'t have a mesh', thing, null)
			main_game_node.get_node('CanvasLayer').add_child(menu_instance)

			
	if event.is_action_pressed('scroll_up') and not in_edit_mode and not main_game_node.in_context_menu and not is_driving:
		weapon_index += 1
		if weapon_index > max_weapons:
			weapon_index = 0
		change_weapon(weapon_index)
	if event.is_action_pressed('scroll_down') and not in_edit_mode and not main_game_node.in_context_menu and not is_driving:
		weapon_index -= 1
		if weapon_index < 0:
			weapon_index = max_weapons
		change_weapon(weapon_index)
		
	if event.is_action_pressed('scroll_up') and is_driving and not is_first_person:
		tps_arm.spring_length += 1
	if event.is_action_pressed('scroll_down') and is_driving and not is_first_person:
		tps_arm.spring_length -= 1
		
	# --- MOUSE CAPTURE TOGGLE (Escape Key) ---
	if event.is_action_pressed("ui_cancel"):
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		else:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

	# --- VIEW TOGGLE (e.g., 'V' Key) ---
	if event.is_action_pressed("toggle_view"):
		is_first_person = not is_first_person
		
		if is_first_person:
			# Collapse arm for FP
			tps_arm.spring_length = 0.0
			
			# reset any rotation or translation on the on the camera pivot
			camera_pivot.rotation = Vector3(0, 0, 0)
			camera_pivot.position = Vector3(0, 1.676, -1)
			
			# TODO: do something about the two weapon cameras
			
		else:
			# Extend arm for TP
			tps_arm.spring_length = tps_distance
			
			# make camera pivot center on player
			camera_pivot.position = Vector3(0, 1.676, 0)
			
	# --- MOUSE LOOK (ONLY when captured) ---
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		
		# Horizontal Rotation (Y-axis): Rotates the CharacterBody3D
		if is_first_person:
			rotate_y(-event.relative.x * mouse_sensitivity)
		else:
			# don't rotate the player, rotate the camera around the player
			camera_pivot.rotate_y(-event.relative.x * mouse_sensitivity)
			
		# Vertical Rotation (X-axis): Rotates the Camera Pivot node
		if camera_pivot:
			if is_first_person:
				camera_pivot.rotate_x(-event.relative.y * mouse_sensitivity)
				# Clamp the vertical rotation
				var cam_rot_x = camera_pivot.rotation.x
				camera_pivot.rotation.x = clamp(cam_rot_x, -CLAMP_ANGLE, CLAMP_ANGLE)
			else:
				# Clamp the vertical rotation

				# 1. Calculate the intended change
				var change = event.relative.y * mouse_sensitivity
				
				# 2. Add change to our tracker and clamp it (e.g., between -90 and 90 degrees)
				# We use radians because rotate_object_local does
				var prev_pitch = tps_pitch
				tps_pitch = clamp(tps_pitch + change, deg_to_rad(-45), deg_to_rad(45))
				
				# 3. Only rotate by the amount that wasn't "cut off" by the clamp
				camera_pivot.rotate_object_local(Vector3.LEFT, tps_pitch - prev_pitch)
				
# Helper function for instantaneous position setting (used at start)
func _set_view_position(target: Vector3):
	if camera:
		camera.global_position = target

func air_move(delta: float, wish_dir: Vector3, current_velocity: Vector3) -> Vector3:
	# Air movement uses a different acceleration value and NO friction
	return accelerate(delta, wish_dir, current_velocity, air_acceleration)

	
func ground_move(delta: float, wish_dir: Vector3, current_velocity: Vector3) -> Vector3:
	@warning_ignore("shadowed_variable")
	var speed = current_velocity.length()
	# SAFETY: Ensure we don't divide by zero speed or zero delta
	if speed > 0.01 and delta > 0:
		var drop = speed * friction * delta
		var new_speed = max(0, speed - drop)
		current_velocity *= (new_speed / speed)
	elif speed < 0.01:
		current_velocity = Vector3.ZERO
		
	return accelerate(delta, wish_dir, current_velocity, acceleration)

func accelerate(delta: float, wish_dir: Vector3, current_velocity: Vector3, accel: float) -> Vector3:
	# SAFETY: If wish_dir is zero, don't accelerate
	if wish_dir.is_zero_approx():
		return current_velocity
		
	var current_speed = current_velocity.dot(wish_dir)
	var add_speed = speed - current_speed
	
	if add_speed <= 0:
		return current_velocity
	
	var accel_speed = accel * delta * speed
	if accel_speed > add_speed:
		accel_speed = add_speed
	
	var final_vel = current_velocity + wish_dir * accel_speed
	
	# FINAL SAFETY: If math explodes, return zero
	return final_vel if final_vel.is_finite() else Vector3.ZERO


func _process(_delta: float) -> void:
	if is_multiplayer_authority(): 
		# sync main camera 3d with the weapon camera3d in the subviewport
		$CanvasLayer/SubViewportContainer/SubViewport/Camera3D.global_transform = $camera_pivot/tps_arm/Camera3D.global_transform
		$CanvasLayer/SubViewportContainer/SubViewport/Camera3D.fov = $camera_pivot/tps_arm/Camera3D.fov
		
		# update health and other player HUD UI elements
		main_game_node.get_node('CanvasLayer/player_HUD/health_value').text = str(int(current_health))
		main_game_node.get_node('CanvasLayer/player_HUD/heart').material.set_shader_parameter("progress", 1.0 * current_health / max_health)
		main_game_node.get_node('CanvasLayer/HBoxContainer/speed').text = 'Speed: ' + str(int(velocity.length()))

		# set the particles to the snow status of the server player
		if main_game_node.get_node('entities/1'):
			self.snow_status = main_game_node.get_node('entities/1').snow_status
			$GPUParticles3D.emitting = snow_status
		
		
# for periodic weather effects
func _on_timer_timeout() -> void:
	# only runs on the server
	if not multiplayer.is_server(): return
	
	print('Server toggling snow')
	var time_til_toggle = randi_range(60, 60*3)
	@warning_ignore("standalone_ternary")
	#rpc('turn_snow_off') if snow_status else rpc('turn_snow_on')
	turn_snow_off() if snow_status else turn_snow_on()

	$GPUParticles3D/Timer.wait_time = time_til_toggle
	$GPUParticles3D/Timer.start()
	#main_game_node.rpc('send_chat', 'Toggled snow', multiplayer.get_unique_id())
	#print($GPUParticles3D.emitting)

#@rpc('any_peer','call_local','reliable')
func turn_snow_on():
	#print(str(multiplayer.get_unique_id()) + ' turned on snow')
	$GPUParticles3D.emitting = true
	snow_status = true
	
#@rpc('any_peer','call_local','reliable')
func turn_snow_off():
	#print(str(multiplayer.get_unique_id()) + ' turned off snow')
	$GPUParticles3D.emitting = false
	snow_status = false
	
func _on_grunt_timer_timeout():
	# The authority rolls the dice
	if randf() <= 0.75:
		# Tell everyone to execute the function
		rpc('play_idle_sound', randi_range(0, len(GlobalVars.idle_sound_streams) - 1))

@rpc('any_peer','call_local','reliable')
func play_jump_sound():
	$jumpSound.play()
	
@rpc('any_peer','call_local','reliable')
func play_idle_sound(index: int):
	$idleSound.stream = GlobalVars.idle_sound_streams[index]
	if not $jumpSound.playing:
		$idleSound.play()
	#print('Sound from ' + str(multiplayer.get_remote_sender_id()) + ' played on ' + str(multiplayer.get_unique_id()))

func hit_scan_attack(damage_amount):
	if aim_ray.is_colliding():
		var body = aim_ray.get_collider() # This is the PhysicsBody3D (Static, Rigid, or Character)
		if body.has_method('damage'):
			if 'IS_PLAYER' in body:
				if body.IS_PLAYER:
					# only damage another player if friendly fire is on!
					# TODO: NOT SECURE, since client can modify, make the check occur only on server
					if host_server_data.friendly_fire:
						body.rpc('damage', damage_amount)
			else:
				body.rpc('damage', damage_amount)

func shoot_projectile():
	rpc('request_spawn_projectile', weapon_index, get_node('weapons/' + weapons[weapon_index].name + '/spawn_position').global_position, aim_ray.to_global(aim_ray.target_position))

@rpc("any_peer", "call_local", "reliable")
@warning_ignore("shadowed_variable")
func request_spawn_projectile(weapon_index: int, origin_pos: Vector3, target_pos: Vector3):
	# This code MUST run on the server to be synced by MultiplayerSpawner
	if not multiplayer.is_server():
		return
		
	var rocket = weapons[weapon_index].projectile_scene.instantiate()
	
	# This forces the rocket nose to point at the ray's impact point
	rocket.look_at_from_position(origin_pos, target_pos, Vector3.UP)
	
	# Add it to the node pointed to by your MultiplayerSpawner's "Spawn Path"
	# Example: adding it to the 'Projectiles' container in your level
	main_game_node.get_node('entities').add_child(rocket, true)


# if the mesh has a next pass highlight shader on the it's override material, highlight it
func set_highlight_mesh(closest_mesh: MeshInstance3D, state:bool = true):
	# highlight this mesh
	var override_mat = closest_mesh.get_surface_override_material(0)
	if override_mat:
		var outline_shader_mat = override_mat.next_pass
		if outline_shader_mat:
			outline_shader_mat.set_shader_parameter('is_active', state)

# exactly as the function says, it checks AABBs
func get_closest_mesh_to_raycast(ray: RayCast3D) -> MeshInstance3D:
	var hit_point = ray.get_collision_point()
	var body = ray.get_collider()
			
	var ray_origin = ray.global_position
	var ray_direction = (hit_point - ray_origin).normalized()
	
	# If you're in the RV only be able to select meshes of shit inside the RV
	if self.in_rv:
		body = main_game_node.get_node('entities/Gmc')
		
	var all_meshes = GlobalVars.get_all_nested_meshes(body)
	#print(all_meshes)
	var best_mesh: MeshInstance3D = null
	var min_error = INF

	for mesh in all_meshes:
		# 1. Local AABB check first to narrow it down
		var local_point = mesh.to_local(hit_point)
		if mesh.get_aabb().has_point(local_point):
			
			# 2. Calculate the 'Error' (Perpendicular distance from ray to mesh center)
			# This distinguishes which mesh the ray is actually 'skewering'
			var mesh_center = mesh.global_position
			var vec_to_center = mesh_center - ray_origin
			
			# Project center onto the ray to find the closest point on the line
			var projection = ray_origin + ray_direction * vec_to_center.dot(ray_direction)
			var distance_to_ray_line = projection.distance_to(mesh_center)
			
			# 3. Choose the mesh with the smallest offset from the ray line
			if distance_to_ray_line < min_error:
				min_error = distance_to_ray_line
				best_mesh = mesh
				
	return best_mesh
