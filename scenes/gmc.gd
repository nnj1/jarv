extends VehicleBody3D

enum Gear { DRIVE, REVERSE }
@export var current_gear = Gear.DRIVE

@export_group("Engine Settings")
@export var max_engine_force: float = 2500.0
@export var max_steer_angle: float = 0.35
@export var brake_strength: float = 80.0
@export var steering_speed: float = 2.5
@export var top_speed_kmh: float = 120.0

@export_group("Stability Settings")
@export var anti_roll_force: float = 0.5
@export var grip_multiplier: float = 2.0

@export_group("Fuel Settings")
@export var max_fuel: float = 100.0
@export var current_fuel: float = 100.0
@export var fuel_consumption_rate: float = 1.5
@export var idle_consumption_rate: float = 0.1

@export_group("Battery Settings")
@export var max_battery: float = 100.0
@export var current_battery: float = 100.0
@export var battery_consumption_rate_high_beams: float = 1.5
@export var battery_consumption_rate_high_beams_idle: float = 0.1
@export var high_beams_status: bool = false

@export_group("Oil Settings")
@export var max_oil: float = 100.0
@export var current_oil: float = 100.0
@export var oil_consumption_rate: float = 0.1

@export_group("Animations")
@export var rotation_speed_multiplier: float = 1.0
@onready var rotating_parts = [$Sketchfab_Scene2/Sketchfab_model/root/GLTF_SceneRootNode/Plane_004_13/Object_22, 
								$Sketchfab_Scene2/Sketchfab_model/root/GLTF_SceneRootNode/Plane_003_12/Object_20,
								$Sketchfab_Scene2/Sketchfab_model/root/GLTF_SceneRootNode/Plane_001_11/Object_18]

const IS_RV:bool = true

@onready var main_game_node = get_tree().get_root().get_node('Node3D')

# --- SPEED TRACKING ---
@export var current_speed_mps: float = 0.0 
@export var current_speed_kmh: float = 0.0 

#var occupants = []
var is_interactable: bool = true
const is_pickable: bool = false
@export var driver_player_id:String = ''
var driver_player_node:Node3D = null

const custom_interact_message:String = 'Press E to repair RV'

func interact(_given_player_node) -> void:
	pass
	# CAN DO RV REPAIRS HERE
	
		#
func _enter_tree() -> void:
	set_multiplayer_authority(1)
	
func _ready() -> void:
	$engineIdleSound.play()
	center_of_mass_mode = VehicleBody3D.CENTER_OF_MASS_MODE_CUSTOM
	center_of_mass = Vector3(0, -0.8, 0)
	
func gear_change():
	current_gear = Gear.REVERSE if current_gear == Gear.DRIVE else Gear.DRIVE

func handbrake():
	brake = brake_strength * 4.0
	
func highbeams():
	high_beams_status = not high_beams_status
	if high_beams_status:
		$left_headlight.spot_range = 300
		$right_headlight.spot_range = 300
	else:
		$left_headlight.spot_range = 70
		$right_headlight.spot_range = 70

@rpc("any_peer","call_local", "reliable")
func network_gear_change():
	current_gear = Gear.REVERSE if current_gear == Gear.DRIVE else Gear.DRIVE

@rpc("any_peer","call_local", "reliable")
func network_handbrake():
	brake = brake_strength * 4.0

@rpc("any_peer","call_local", "reliable")
func network_highbeams():
	high_beams_status = not high_beams_status
	if high_beams_status:
		$left_headlight.spot_range = 300
		$right_headlight.spot_range = 300
	else:
		$left_headlight.spot_range = 70
		$right_headlight.spot_range = 70

func lock_player_to_driver_seat(delta) -> void:
	if not driver_player_node: return
	
	var seat_node = get_node('drivers_seat')
	# smooth rotation
	var target_quat = seat_node.get_node('driver_position').global_transform.basis.get_rotation_quaternion()
	var current_quat = driver_player_node.global_transform.basis.get_rotation_quaternion()
	
	# SAFETY CHECK 1: Ensure quaternions are valid and not identical
	if current_quat.is_finite() and target_quat.is_finite():
		# Only slerp if there is actually a difference to calculate
		if not current_quat.is_equal_approx(target_quat):
			var final_quat = current_quat.slerp(target_quat, 5 * delta)
			
			# SAFETY CHECK 2: Final validation before applying to the GPU
			if final_quat.is_finite():
				# Apply rotation while preserving current scale
				var s = driver_player_node.global_basis.get_scale()
				if s.is_finite():
					driver_player_node.rpc('move_to_position_and_rotation', seat_node.get_node('driver_position').global_position, Basis(final_quat).scaled(s))
	
func _process(_delta: float) -> void:
	# Update UI (runs on all clients)
	main_game_node.get_node('CanvasLayer/RV_HUD/HBoxContainer2/VBoxContainer/gear').text = ['Drive', 'Reverse'][current_gear]
	main_game_node.get_node('CanvasLayer/RV_HUD/HBoxContainer2/VBoxContainer/car_speed').text = str(int(current_speed_kmh)) + ' kmh'
	main_game_node.get_node("CanvasLayer/RV_HUD/fuelpercent").text = str(int(current_fuel)) + "L"
	main_game_node.get_node("CanvasLayer/RV_HUD/oilpercent").text = str(int(current_oil)) + "%"
	main_game_node.get_node("CanvasLayer/RV_HUD/batterypercent").text = str(int(current_battery)) + "%"
	
func _physics_process(delta: float) -> void:
	
	# CLIENT-SIDE SMOOTHING
	#if not multiplayer.is_server():
		## The client shouldn't run engine logic, 
		## but it SHOULD keep moving the car based on velocity
		## so it doesn't "stop" between server updates.
		#var velocity_clamped = linear_velocity.length()
		#if velocity_clamped > 0.1:
			## This 'predicts' where the car should be
			## preventing the 'snap' jitter.
			#return 
		#else:
			#return
			
	if not is_multiplayer_authority(): return
	
	# 1. Update Speed Variables
	current_speed_mps = linear_velocity.length()
	current_speed_kmh = current_speed_mps * 3.6
	
	# 2. Fuel Consumption Logic
	if current_fuel > 0:
		current_fuel -= idle_consumption_rate * delta
	else:
		current_fuel = 0
		if $engineIdleSound.playing: $engineIdleSound.stop()
		if $accelerateSound.playing: $accelerateSound.stop()

	# 2. Battery Consumption Logic
	if current_battery > 0:
		if high_beams_status:
			current_battery -= battery_consumption_rate_high_beams * delta
		else:
			current_battery -= battery_consumption_rate_high_beams_idle * delta
	else:
		# prevent battery from dipping below zero
		current_battery = 0

	# 3. ROTATION LOGIC
	for rotating_part in rotating_parts:
		if rotating_part:
			var direction = 1.0
			if linear_velocity.dot(global_transform.basis.z) > 0.1:
				direction = -1.0
			rotating_part.rotate_x(current_speed_mps * rotation_speed_multiplier * direction * delta * -1)
	
	# Grab the input variables from the player who is the driver
	# by default the player host will be the driver (with the arrow keys though)
	var steer_input = 0.0
	var forward_input = 0.0
	var back_input = 0.0
	@warning_ignore("unused_variable")
	var gear_key_just_pressed = null
	@warning_ignore("unused_variable")
	var handbrake_key_pressed = null
	
	# if there is a driver
	if driver_player_id != '':
		driver_player_node = main_game_node.get_node('entities/' + driver_player_id)
		# HAVE THE DRIVING PLAYER CONTROL THE CAR
		steer_input = driver_player_node.steer_input
		forward_input = driver_player_node.forward_input
		back_input = driver_player_node.back_input
		#gear_key_just_pressed = driver_player_node.gear_key_just_pressed
		#handbrake_key_pressed = driver_player_node.handbrake_key_pressed
		
		#if gear_key_just_pressed:
		#	gear_change()
		#if handbrake_key_pressed:
		#	handbrake()
		#print('Being driven by ' + str(driver_player_node))
	
		lock_player_to_driver_seat(delta)
		
	# no driver, then the server player is sending the inputs (but via arrow keys)
	elif driver_player_id == '':
		steer_input = Input.get_action_strength("turn_left") - Input.get_action_strength("turn_right")
		forward_input = Input.get_action_strength("drive_forward")
		back_input = Input.get_action_strength("drive_back")
		if Input.is_action_just_pressed("shift_gear"):
			gear_change()
		if Input.is_action_pressed("handbrake"):
			handbrake()
		if Input.is_action_just_pressed("highbeams"):
			highbeams()
		#print('Being driven by default server')
	
	# 5. Steering and Movement Logic
	steering = move_toward(steering, steer_input * max_steer_angle, delta * steering_speed)
	
	engine_force = 0.0
	brake = 0.0
	
	# --- NEW: ROLLING RESISTANCE ---
	# Apply a base friction if the player isn't pressing the gas/brake
	if forward_input == 0 and back_input == 0:
		brake = brake_strength * 0.3

	if current_fuel > 0:
		if current_speed_kmh < top_speed_kmh:
			if current_gear == Gear.DRIVE:
				if forward_input > 0:
					engine_force = forward_input * max_engine_force
					current_fuel -= fuel_consumption_rate * forward_input * delta
				if back_input > 0:
					brake = back_input * brake_strength
			elif current_gear == Gear.REVERSE:
				if back_input > 0:
					engine_force = -back_input * (max_engine_force * 0.6)
					current_fuel -= fuel_consumption_rate * back_input * delta
				if forward_input > 0:
					brake = forward_input * brake_strength
	else:
		# --- NEW: OUT OF FUEL DRAG ---
		engine_force = 0.0
		# Apply heavier braking when out of fuel so the car doesn't slide forever
		brake = brake_strength * 0.5 

	# Audio Logic
	if engine_force != 0 and current_fuel > 0:
		if not $accelerateSound.playing:
			$accelerateSound.play()
	else:
		$accelerateSound.stop()
	
	_apply_stability_logic()

func refuel(amount: float = 1000) -> void:
	current_fuel = clamp(current_fuel + amount, 0, max_fuel)
	#if current_fuel > 0 and not $engineIdleSound.playing:
	#	$engineIdleSound.play()
	# ts doesn't belong here

func recharge(amount: float = 1000) -> void:
	current_fuel = clamp(current_battery + amount, 0, max_battery)

func _apply_stability_logic():
	var side_velocity = global_transform.basis.x.dot(linear_velocity)
	apply_central_force(-global_transform.basis.x * side_velocity * mass * grip_multiplier)
	apply_central_force(Vector3.DOWN * mass * 0.5)

# local functions for determining whether we can repair the vehicle
@warning_ignore("unused_parameter")
func _on_inner_volume_body_entered(body: Node3D) -> void:
	is_interactable = false

@warning_ignore("unused_parameter")
func _on_inner_volume_body_exited(body: Node3D) -> void:
	is_interactable = true 
