extends ItemBody

@export_group("Patrol Settings")
@export var patrol_range: float = 45.0 # Degrees left/right
@export var patrol_speed: float = 0.5

@export_group("Tracking Settings")
@export var turn_speed: float = 8.0

@onready var turret_body: Node3D = $model/main_turret # Your moving part

var target: Node3D = null
var time_passed: float = 0.0
var original_scale: Vector3 # Store the scale to prevent shrinking

func _ready() -> void:
	super._ready()
	
	# Store the initial scale so we can force it to stay consistent
	original_scale = turret_body.scale
	
	# Connect signals (Ensure your Area3D is named "Area3D")
	$Area3D.body_entered.connect(_on_target_entered)
	$Area3D.body_exited.connect(_on_target_exited)

func _physics_process(delta: float) -> void:
	if target and is_instance_valid(target):
		_track_target(delta)
	else:
		_patrol(delta)

func _patrol(delta: float) -> void:
	time_passed += delta * patrol_speed
	var target_angle = sin(time_passed) * deg_to_rad(patrol_range)
	
	# Smoothly rotate the Y axis while preserving scale
	turret_body.rotation.y = lerp_angle(turret_body.rotation.y, target_angle, delta * turn_speed)
	turret_body.scale = original_scale

func _track_target(delta: float) -> void:
	# 1. Get direction (ignore verticality to prevent the turret from tipping)
	var target_pos = target.global_position
	target_pos.y = turret_body.global_position.y
	
	var look_dir = (target_pos - turret_body.global_position).normalized()
	if look_dir.is_zero_approx(): return

	# 2. Calculate the target rotation (Basis)
	var target_basis = Basis.looking_at(look_dir, Vector3.UP)
	var target_quat = target_basis.get_rotation_quaternion()
	
	# 3. Slerp (Spherical Linear Interpolation) for smooth rotation
	var current_quat = turret_body.global_transform.basis.get_rotation_quaternion()
	var final_quat = current_quat.slerp(target_quat, delta * turn_speed)
	
	# 4. Apply back to global_basis and RE-APPLY scale
	# If we don't re-apply scale, 'looking_at' resets scale to (1,1,1)
	turret_body.global_basis = Basis(final_quat)
	turret_body.scale = original_scale

# --- Signal Callbacks ---

func _on_target_entered(body: Node3D) -> void:
	# Replace "player" with whatever group your target is in
	if body.is_in_group("player"):
		target = body

func _on_target_exited(body: Node3D) -> void:
	if body == target:
		target = null
