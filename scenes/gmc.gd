extends VehicleBody3D

enum Gear { DRIVE, REVERSE }
var current_gear = Gear.DRIVE

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

@export_group("Animations")
@export var rotation_speed_multiplier: float = 1.0
@onready var rotating_parts = [$Sketchfab_Scene2/Sketchfab_model/root/GLTF_SceneRootNode/Plane_004_13/Object_22, 
								$Sketchfab_Scene2/Sketchfab_model/root/GLTF_SceneRootNode/Plane_003_12/Object_20,
								$Sketchfab_Scene2/Sketchfab_model/root/GLTF_SceneRootNode/Plane_001_11/Object_18]

@onready var main_game_node = get_tree().get_root().get_node('Node3D')

# --- SPEED TRACKING ---
var current_speed_mps: float = 0.0 
var current_speed_kmh: float = 0.0 

var occupants = []
const is_interactable: bool = true
const is_pickable: bool = false

func interact(given_player_node) -> void:
	if not given_player_node in occupants:
		print(str(given_player_node) + ' entered GMC RV')
		occupants.append(given_player_node)
		set_collision_mask_value(2, false)
		given_player_node.global_position = $entrance_point.global_position
		set_collision_mask_value(2, true)
		
func _ready() -> void:
	$engineIdleSound.play()
	center_of_mass_mode = VehicleBody3D.CENTER_OF_MASS_MODE_CUSTOM
	center_of_mass = Vector3(0, -0.8, 0)
	
func _physics_process(delta: float) -> void:
	# 1. Update Speed Variables
	current_speed_mps = linear_velocity.length()
	current_speed_kmh = current_speed_mps * 3.6
	
	# Update UI
	main_game_node.get_node('CanvasLayer/RV_HUD/HBoxContainer2/VBoxContainer/gear').text = ['Drive', 'Reverse'][current_gear]
	main_game_node.get_node('CanvasLayer/RV_HUD/HBoxContainer2/VBoxContainer/car_speed').text = str(int(current_speed_kmh)) + ' kmh'
	main_game_node.get_node("CanvasLayer/RV_HUD/fuelpercent").text = str(int(current_fuel)) + "L"
	
	# 2. Fuel Consumption Logic
	if current_fuel > 0:
		current_fuel -= idle_consumption_rate * delta
	else:
		current_fuel = 0
		if $engineIdleSound.playing: $engineIdleSound.stop()
		if $accelerateSound.playing: $accelerateSound.stop()

	# 3. ROTATION LOGIC
	for rotating_part in rotating_parts:
		if rotating_part:
			var direction = 1.0
			if linear_velocity.dot(global_transform.basis.z) > 0.1:
				direction = -1.0
			rotating_part.rotate_x(current_speed_mps * rotation_speed_multiplier * direction * delta * -1)

	# 4. Gear Switching
	if Input.is_action_just_pressed("shift_gear"):
		current_gear = Gear.REVERSE if current_gear == Gear.DRIVE else Gear.DRIVE
	
	# 5. Steering Logic
	var steer_input = Input.get_action_strength("turn_left") - Input.get_action_strength("turn_right")
	steering = move_toward(steering, steer_input * max_steer_angle, delta * steering_speed)
	
	# 6. Movement Logic
	var forward_input = Input.get_action_strength("drive_forward")
	var back_input = Input.get_action_strength("drive_back")
	
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
	
	if Input.is_action_pressed("handbrake"):
		brake = brake_strength * 4.0

	_apply_stability_logic()

func refuel(amount: float) -> void:
	current_fuel = clamp(current_fuel + amount, 0, max_fuel)
	if current_fuel > 0 and not $engineIdleSound.playing:
		$engineIdleSound.play()

func _apply_stability_logic():
	var side_velocity = global_transform.basis.x.dot(linear_velocity)
	apply_central_force(-global_transform.basis.x * side_velocity * mass * grip_multiplier)
	apply_central_force(Vector3.DOWN * mass * 0.5)
