extends CharacterBody3D

# --- Exported Variables ---
@export var speed: float = 5.0
@export var jump_velocity: float = 4.5
@export var mouse_sensitivity: float = 0.002
@export var camera_pivot: Node3D        # Drag the Camera Pivot (Node3D) here
@export var tps_arm: SpringArm3D       # Drag the TPS_Arm (SpringArm3D) here
@export var fp_position: Node3D        # Drag the FP_Pos (Node3D) here
@export var transition_speed: float = 10.0 # How fast the camera moves when switching
@export var tps_distance: float = 4.0   # The maximum length of the SpringArm in TP mode

# --- Constants ---
const CLAMP_ANGLE: float = 1.2
const GRAVITY: float = 9.8

# --- State Variables ---
var is_first_person: bool = true
var camera: Camera3D

func _ready():
	# Lock the mouse at start
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	
	# Get camera reference and set initial view
	camera = tps_arm.get_child(0) as Camera3D
	_set_view_position(fp_position.global_position)
	tps_arm.spring_length = 0.0 # Start SpringArm collapsed for FP

# 1. Physics Movement and Camera Interpolation
func _physics_process(delta):
	# --- MOVEMENT (Same as original) ---
	if not is_on_floor():
		velocity.y -= GRAVITY * delta

	if is_on_floor() and Input.is_action_just_pressed("jump"):
		velocity.y = jump_velocity

	var input_dir: Vector2 = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var direction: Vector3 = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()

	if direction:
		velocity.x = direction.x * speed
		velocity.z = direction.z * speed
	else:
		velocity.x = move_toward(velocity.x, 0, speed)
		velocity.z = move_toward(velocity.z, 0, speed)

	move_and_slide()
	
	# --- CAMERA INTERPOLATION (New for smooth switching) ---
	var target_position: Vector3
	if is_first_person:
		target_position = fp_position.global_position
	else:
		# Target the SpringArm's global position when extended
		target_position = tps_arm.global_position
		
	camera.global_position = camera.global_position.lerp(target_position, delta * transition_speed)


# 2. Input Handling (Mouse Look and Toggles)
func _unhandled_input(event):
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
