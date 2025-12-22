extends VehicleBody3D

# --- Node References (Set in the Inspector) ---
@export var front_left_wheel: VehicleWheel3D
@export var front_right_wheel: VehicleWheel3D
@export var back_left_wheel: VehicleWheel3D
@export var back_right_wheel: VehicleWheel3D

# These are the actual 3D MeshInstance3D nodes inside the wheels
@export var fl_mesh: Node3D
@export var fr_mesh: Node3D
@export var bl_mesh: Node3D
@export var br_mesh: Node3D

# --- Car Control Properties ---
@export var max_steering_angle: float = 0.5 # Max steering angle in radians (~28 degrees)
@export var max_engine_force: float = 4000.0
@export var max_brake_force: float = 100.0

var current_engine_force: float = 0.0
var current_brake_force: float = 0.0
var current_steer: float = 0.0

@warning_ignore("unused_parameter")
func _physics_process(delta: float):
	# 1. Handle Input
	var accelerate_input: float = Input.get_axis("drive_back", "drive_forward")
	var steer_input: float = Input.get_axis("turn_right", "turn_left")

	# 2. Steering (Apply steering angle as before)
	current_steer = steer_input * max_steering_angle
	front_left_wheel.steering = current_steer
	front_right_wheel.steering = current_steer
	
	# Get the car's current forward speed (positive when moving forward)
	# The dot product of linear_velocity and the car's forward vector (-Z)
	var forward_speed: float = linear_velocity.dot(-global_transform.basis.z)
	var is_moving_forward: bool = forward_speed > 0.1 # Check if speed is positive
	@warning_ignore("unused_variable")
	var is_moving_backward: bool = forward_speed < -0.1 # Check if speed is negative

	# 3. Acceleration, Braking, and Reversing Logic
	
	if accelerate_input > 0: # --- FORWARD INPUT ---
		current_engine_force = max_engine_force * accelerate_input
		current_brake_force = 0.0
	
	elif accelerate_input < 0: # --- BACKWARD INPUT (Brake/Reverse) ---
		if is_moving_forward:
			# Moving forward, so input acts as a BRAKE
			current_engine_force = 0.0
			current_brake_force = max_brake_force
		else:
			# Stopped or moving backward, so input acts as REVERSE ACCELERATION
			# Apply negative engine force (reverse)
			current_engine_force = max_engine_force * accelerate_input * 30 # Use half force for reverse
			current_brake_force = 0.0
	
	else: # --- NO INPUT ---
		# Coasting: Reset forces
		current_engine_force = 0.0
		current_brake_force = 0.0

	# 4. Apply Forces to the VehicleBody3D
	engine_force = current_engine_force
	brake = current_brake_force
	
	# 5. Animate Wheel Meshes
	# pdate Front Wheels (Steering + Spinning)
	update_wheel_transform(front_left_wheel, fl_mesh, delta)
	update_wheel_transform(front_right_wheel, fr_mesh, delta)

	# Update Rear Wheels (Just Spinning)
	update_wheel_transform(back_left_wheel, bl_mesh, delta)
	update_wheel_transform(back_right_wheel, br_mesh, delta)


func update_wheel_transform(wheel_node: VehicleWheel3D, mesh_node: Node3D, delta: float):
	if not wheel_node or not mesh_node:
		return
	
	# --- SPINNING (X-Axis) ---
	# RPM to Radians per second: (RPM * 2 * PI) / 60
	var rpm = wheel_node.get_rpm()
	var spin_speed = (rpm * TAU) / 60.0
	mesh_node.rotate_x(spin_speed * delta)
	
	# --- STEERING (Y-Axis) ---
	# We set the Y rotation directly to match the wheel's steering angle
	mesh_node.rotation.y = wheel_node.steering
