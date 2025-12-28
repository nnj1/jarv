extends CharacterBody3D

@onready var main_game_node = get_tree().get_root().get_node('Node3D')

# --- Exported Variables ---
@export var speed: float = 10
@export var jump_velocity: float = 9
@export var mouse_sensitivity: float = 0.002
@export var camera_pivot: Node3D        # Drag the Camera Pivot (Node3D) here
@export var tps_arm: SpringArm3D       # Drag the TPS_Arm (SpringArm3D) here
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
var weapon_index = 1
var max_weapons = 3
@export var max_health = 100
@export var current_health = 100
var health_decay_rate = 0.1
var recoil_velocity: Vector3 = Vector3.ZERO

@export var skin_color = Color(1,0,0)
@export var username:String = 'something'

@export var snow_status:bool = true

# Variables the GMC will hook into for driving purposes
@export var steer_input = 0.0
@export var forward_input = 0.0
@export var back_input = 0.0
@export var gear_key_just_pressed:bool = false
@export var handbrake_key_pressed:bool = false

var weapons = [
	{
		'name': 'hand',
		'reticle': 0,
		'class':'MELEE'
	},
	{
		'name': 'grenadelauncher',
		'reticle': 82,
		'recoil_force':10,
		'class':'SINGLE'
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
	base_mat.next_pass = base_mat.next_pass.duplicate()
	base_mat.next_pass.set_shader_parameter("blue_replacement_color", skin_color)

func change_weapon(index:  int = weapon_index):
	# drop any held items
	if entity_held:
		entity_held.drop()
		self.entity_held = null
	for child in $weapons.get_children():
		child.visible = false
	$weapons.get_children()[index].visible = true
	main_game_node.get_node('CanvasLayer/crosshair').texture = GlobalVars.get_cursor_texture(weapons[index].reticle, 20, 10)	
	$weaponswapSound.play()

#func start_driving(_given_seat_node):
	#main_game_node.get_node('entities/Gmc').driver_player_id = str(multiplayer.get_unique_id())
	#self.seat_node = main_game_node.get_node('entities/Gmc/drivers_seat')#given_seat_node
	#self.is_driving = true
	#
#func stop_driving():
	#self.is_driving = false
	#main_game_node.get_node('entities/Gmc').driver_player_id = ''
	#self.seat_node = null
	## reset player rotation
	#self.rotation = Vector3(0,0,0)
	
func start_driving(_given_seat_node):
	# 1. Set local state so the Client enters the loop immediately
	self.is_driving = true
	
	# 2. Assign the seat node locally so the position lock works
	self.seat_node = main_game_node.get_node('entities/Gmc/drivers_seat')
	
	# 3. Tell the server to register us (Host logic)
	rpc_id(1, "server_register_driver", true)
	
	# disable the player's main collision shape
	$CollisionShape3D.disabled = true
	
func stop_driving():
	rpc_id(1, "server_register_driver", false)
	self.is_driving = false
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
		# delta ensures the decay is consistent regardless of frame rate
		current_health -= health_decay_rate * delta
		
		# Prevent health from going below zero
		current_health = max(current_health, 0)
		
func _enter_tree() -> void:
	set_multiplayer_authority(name.to_int())
	
@rpc("any_peer","call_remote","reliable")
func on_new_player(player_id: int) -> void:
	# if the new player who joins is not yourself, turn off the GPU particles
	var player_node = main_game_node.get_node('entities/' + str(player_id))
	if player_id != multiplayer.get_unique_id():
		player_node.get_node('GPUParticles3D').hide()

func _ready():
	if is_multiplayer_authority(): #and DisplayServer.window_is_focused():
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
	
	if not is_multiplayer_authority(): return
	
	# code for dropping held items
	if Input.is_action_just_pressed('interact') and entity_held and not main_game_node.typing_chat:
		entity_held.drop()
		self.entity_held = null
	
	if $camera_pivot/tps_arm/Camera3D/RayCast3D.is_colliding():
		var target = $camera_pivot/tps_arm/Camera3D/RayCast3D.get_collider()
		main_game_node.get_node('CanvasLayer/HBoxContainer/target').text = str(target)
		if 'is_interactable' in target and entity_held == null:
			if target.is_interactable:
				var message = target.custom_interact_message if ('custom_interact_message' in target) else 'Press E to interact'
				# show the interaction message if the target isn't pickable
				if not target.is_pickable:
					main_game_node.get_node('CanvasLayer/interact_message').text = message
					main_game_node.get_node('CanvasLayer/interact_message').visible = true
				# show the interaction message only if the hand is active when the target is pickable
				elif target.is_pickable:
					if weapons[weapon_index].name == 'hand':
						main_game_node.get_node('CanvasLayer/interact_message').text = message
						main_game_node.get_node('CanvasLayer/interact_message').visible = true
				
				# do the actual interaction if the player presses the key
				if Input.is_action_just_pressed('interact') and not main_game_node.typing_chat:
					target.interact(self)
	else:
		# reset to default message
		main_game_node.get_node('CanvasLayer/interact_message').text = 'Press E to interact'
		main_game_node.get_node('CanvasLayer/interact_message').visible = false
		
	# --- MOVEMENT (Same as original) ---
	if not is_driving:
		# 1. Handle Gravity
		if not is_on_floor():
			velocity.y -= GRAVITY * delta

		# 2. Handle Jump (Standard Quake doesn't have jump cooldown)
		if is_on_floor() and Input.is_action_pressed("jump") and not main_game_node.typing_chat:
			velocity.y = jump_velocity
			rpc('play_jump_sound')

		# 3. Get Input Direction
		var input_dir = Vector3.ZERO
		if not main_game_node.typing_chat:
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
		
		# attack animation for all kinds of weapons
		# BURST CLASS: this means the weapon that is currently equipped is shootable
		if weapons[weapon_index].class == 'BURST':
			if 'recoil_force' in weapons[weapon_index].keys():
				var weapon_animation_player = get_node_or_null('weapons/' + weapons[weapon_index].name + '/AnimationPlayer')
				if Input.is_action_pressed('shoot'):
					# play the shoot animation for the respective weapon
					if weapon_animation_player:
						if not weapon_animation_player.is_playing():
							weapon_animation_player.play('attack')
							
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
					
		# finally, we can move and slide (we are not driving the RV in this case)
		move_and_slide()
		
	elif seat_node and is_driving:
		
		# in driving mode
		self.steer_input = Input.get_action_strength("move_left") - Input.get_action_strength("move_right")
		self.forward_input = Input.get_action_strength("move_forward")
		self.back_input = Input.get_action_strength("move_back") 

		if Input.is_action_just_pressed('shift_gear'):
			self.gear_key_just_pressed = true
			seat_node.get_parent().rpc_id(1, 'network_gear_change')
		else:
			self.gear_key_just_pressed = false
		
		if Input.is_action_pressed('handbrake'):
			self.handbrake_key_pressed = true
			seat_node.get_parent().rpc_id(1, 'network_handbrake')
		else:
			self.handbrake_key_pressed = false
		
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
	elif event.is_action_released("zoom"):
		is_zooming = false
		
	if event.is_action_pressed('scroll_up'):
		weapon_index += 1
		if weapon_index > max_weapons:
			weapon_index = 0
		change_weapon(weapon_index)
	if event.is_action_pressed('scroll_down'):
		weapon_index -= 1
		if weapon_index < 0:
			weapon_index = max_weapons
		change_weapon(weapon_index)
		
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
		else:
			# Extend arm for TP
			tps_arm.spring_length = tps_distance

	# --- MOUSE LOOK (ONLY when captured) ---
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		# Horizontal Rotation (Y-axis): Rotates the CharacterBody3D
		rotate_y(-event.relative.x * mouse_sensitivity)
		
		# Vertical Rotation (X-axis): Rotates the Camera Pivot node
		if camera_pivot:
			camera_pivot.rotate_x(-event.relative.y * mouse_sensitivity)
			
			# Clamp the vertical rotation
			var cam_rot_x = camera_pivot.rotation.x
			camera_pivot.rotation.x = clamp(cam_rot_x, -CLAMP_ANGLE, CLAMP_ANGLE)

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


func _process(delta: float) -> void:
	if is_multiplayer_authority(): 
		# sync main camera 3d with the weapon camera3d in the subviewport
		$CanvasLayer/SubViewportContainer/SubViewport/Camera3D.global_transform = $camera_pivot/tps_arm/Camera3D.global_transform
		$CanvasLayer/SubViewportContainer/SubViewport/Camera3D.fov = $camera_pivot/tps_arm/Camera3D.fov
		
		# update health and other player HUD UI elements and decay health
		decay_health(delta)
		main_game_node.get_node('CanvasLayer/player_HUD/health_value').text = str(int(current_health))
		main_game_node.get_node('CanvasLayer/player_HUD/heart').material.set_shader_parameter("progress", 1.0 * current_health / max_health)
		main_game_node.get_node('CanvasLayer/HBoxContainer/speed').text = 'Speed: ' + str(int(velocity.length()))

		# set the particles to the snow status of the server player
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
