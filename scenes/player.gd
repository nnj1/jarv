extends CharacterBody3D

@onready var main_game_node = get_tree().get_root().get_node('Node3D')

# --- Exported Variables ---
@export var speed: float = 10
@export var jump_velocity: float = 4.5
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
var is_driving:bool = false
var seat_node: Node3D = null

# --- Constants ---
const CLAMP_ANGLE: float = 1.2
const GRAVITY: float = 9.8
const FOV_KICK: bool = true

# --- State Variables ---
var is_first_person: bool = true
var camera: Camera3D
var weapon_index = 0
var max_weapons = 199

func start_driving(given_seat_node):
	is_driving = true
	seat_node = given_seat_node

func stop_driving():
	is_driving = false
	seat_node = null

func _ready():
	if is_multiplayer_authority() and DisplayServer.window_is_focused():
		# Lock the mouse at start
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		
		# set a crosshair
		main_game_node.get_node('CanvasLayer/crosshair').texture = GlobalVars.get_cursor_texture(weapon_index, 20, 10)

		# Get camera reference and set initial view
		camera = tps_arm.get_child(0) as Camera3D
		camera.make_current()
		
		_set_view_position(fp_position.global_position)
		tps_arm.spring_length = 0.0 # Start SpringArm collapsed for FP

# 1. Physics Movement and Camera Interpolation
func _physics_process(delta):
	
	if not is_multiplayer_authority(): return
	
	if $camera_pivot/tps_arm/Camera3D/RayCast3D.is_colliding():
		var target = $camera_pivot/tps_arm/Camera3D/RayCast3D.get_collider()
		main_game_node.get_node('CanvasLayer/HBoxContainer/target').text = str(target)
		if 'is_interactable' in target:
			if target.is_interactable:
				# show the interaction message
				if 'custom_interact_message' in target:
					if target.custom_interact_message:
						main_game_node.get_node('CanvasLayer/interact_message').text = target.custom_interact_message
				main_game_node.get_node('CanvasLayer/interact_message').visible = true
				if Input.is_action_just_pressed('interact'):
					target.interact(self)
	else:
		main_game_node.get_node('CanvasLayer/interact_message').text = 'Press E to interact'
		main_game_node.get_node('CanvasLayer/interact_message').visible = false
		
	# --- MOVEMENT (Same as original) ---
	if not is_driving:
		# 1. Handle Gravity
		if not is_on_floor():
			velocity.y -= GRAVITY * delta

		# 2. Handle Jump (Standard Quake doesn't have jump cooldown)
		if is_on_floor() and Input.is_action_pressed("jump"):
			velocity.y = jump_velocity

		# 3. Get Input Direction
		var input_dir = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
		var wish_dir = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()

		# 4. Apply Quake Physics
		if is_on_floor():
			velocity = ground_move(delta, wish_dir, velocity)
		else:
			velocity = air_move(delta, wish_dir, velocity)

		move_and_slide()
		main_game_node.get_node('CanvasLayer/HBoxContainer/speed').text = 'Speed: ' + str(int(velocity.length()))
	else:
		# in driving mode
		
		# lock position
		self.global_position = seat_node.get_node('driver_position').global_position
		
		# smooth rotation
		var target_quat =  seat_node.get_node('driver_position').global_transform.basis.get_rotation_quaternion()
		var current_quat = self.global_transform.basis.get_rotation_quaternion()
		# Interpolate between current and target
		var final_quat = current_quat.slerp(target_quat, 5 * delta)
		
		# Apply back to global basis
		global_transform.basis = Basis(final_quat).scaled(global_basis.get_scale())
	
	# --- CAMERA INTERPOLATION (New for smooth switching) ---
	var target_position: Vector3
	if is_first_person:
		target_position = fp_position.global_position
	else:
		# Target the SpringArm's global position when extended
		target_position = tps_arm.global_position
	
	if camera:
		camera.global_position = camera.global_position.lerp(target_position, delta * transition_speed)
	
	if camera:
		# Determine which FOV to aim for
		var target_fov = zoom_fov if is_zooming else default_fov
		# Interpolate the camera's FOV
		camera.fov = lerp(camera.fov, target_fov, delta * zoom_speed)
		
	# Inside _physics_process
	if FOV_KICK:
		var horizontal_speed = Vector3(velocity.x, 0, velocity.z).length()
		var target_fov = zoom_fov if is_zooming else (default_fov + (horizontal_speed * 0.5))
		camera.fov = lerp(camera.fov, target_fov, delta * 8.0)

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
		main_game_node.get_node('CanvasLayer/crosshair').texture = GlobalVars.get_cursor_texture(weapon_index, 20, 10)
	if event.is_action_pressed('scroll_down'):
		weapon_index -= 1
		if weapon_index < 0:
			weapon_index = max_weapons
		main_game_node.get_node('CanvasLayer/crosshair').texture = GlobalVars.get_cursor_texture(weapon_index, 20, 10)	
		
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

func ground_move(delta: float, wish_dir: Vector3, current_velocity: Vector3) -> Vector3:
	# Apply friction
	@warning_ignore("shadowed_variable")
	var speed = current_velocity.length()
	if speed != 0:
		var drop = speed * friction * delta
		current_velocity *= max(0, speed - drop) / speed

	return accelerate(delta, wish_dir, current_velocity, acceleration)

func air_move(delta: float, wish_dir: Vector3, current_velocity: Vector3) -> Vector3:
	# Air movement uses a different acceleration value and NO friction
	return accelerate(delta, wish_dir, current_velocity, air_acceleration)

func accelerate(delta: float, wish_dir: Vector3, current_velocity: Vector3, accel: float) -> Vector3:
	# This is the "secret sauce" of air strafing
	var current_speed = current_velocity.dot(wish_dir)
	var add_speed = speed - current_speed
	
	if add_speed <= 0:
		return current_velocity
	
	var accel_speed = accel * delta * speed
	if accel_speed > add_speed:
		accel_speed = add_speed
	
	return current_velocity + wish_dir * accel_speed
