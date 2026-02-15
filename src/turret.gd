extends ItemBody

@export_group("Patrol Settings")
@export var patrol_range: float = 45.0
@export var patrol_speed: float = 0.5
@export var patrol_pitch_range: float = 8.0
@export var patrol_pitch_speed: float = 0.8 

@export_group("Tracking Settings")
@export var turn_speed: float = 8.0
@export var aim_height_offset: float = 1.0

@export_group("Laser Settings")
@export var laser_enabled: bool = true
@export var particle_speed: float = 1500.0 # Set high for "instant" growth/shrink

@onready var turret_body: Node3D = $model/main_turret
@onready var gun_pivot: Marker3D = $model/main_turret/hinge
@onready var laser_ray: RayCast3D = $model/main_turret/hinge/LaserRay
@onready var laser_particles: GPUParticles3D = $model/main_turret/hinge/LaserParticles

var targets: Array[Node3D] = []
var current_target: Node3D = null
var time_passed: float = 0.0
var body_scale: Vector3 
var gun_scale: Vector3
var ray_max_length: float = 50.0 

func _ready() -> void:
	super._ready()
	body_scale = turret_body.scale
	gun_scale = gun_pivot.scale
	
	# Sync RayCast length from Editor
	ray_max_length = laser_ray.target_position.length()
	
	# Force particles to be high-speed
	var mat = laser_particles.process_material as ParticleProcessMaterial
	if mat:
		mat.initial_velocity_min = particle_speed
		mat.initial_velocity_max = particle_speed
	
	set_laser_state(laser_enabled)
	
	$Area3D.body_entered.connect(_on_target_entered)
	$Area3D.body_exited.connect(_on_target_exited)

func _physics_process(delta: float) -> void:
	_update_target_list()
	
	if laser_enabled:
		_update_particle_laser()
	
	if current_target:
		_track_target(delta)
	else:
		_patrol(delta)

func set_laser_state(active: bool) -> void:
	laser_enabled = active
	laser_particles.emitting = active
	laser_ray.enabled = active
	if not active:
		laser_particles.restart()

func _update_particle_laser() -> void:
	if laser_ray.is_colliding():
		var coll_point = laser_ray.get_collision_point()
		var dist = laser_particles.global_position.distance_to(coll_point)
		
		# High speed (1500) results in a very low lifetime (e.g. 0.02s)
		# This makes the beam feel physically attached to the target
		laser_particles.lifetime = max(0.001, (dist - 0.05) / particle_speed)
	else:
		laser_particles.lifetime = ray_max_length / particle_speed

func _update_target_list() -> void:
	targets = targets.filter(func(t): return is_instance_valid(t))
	current_target = _get_closest_target()

func _get_closest_target() -> Node3D:
	if targets.is_empty(): return null
	var closest: Node3D = null
	var min_dist: float = INF
	for t in targets:
		var dist = global_position.distance_to(t.global_position)
		if dist < min_dist:
			min_dist = dist
			closest = t
	return closest

func _patrol(delta: float) -> void:
	time_passed += delta
	var yaw = sin(time_passed * patrol_speed) * deg_to_rad(patrol_range)
	var pitch = sin(time_passed * patrol_pitch_speed) * deg_to_rad(patrol_pitch_range)
	
	turret_body.rotation.y = lerp_angle(turret_body.rotation.y, yaw, delta * turn_speed)
	gun_pivot.rotation.x = lerp_angle(gun_pivot.rotation.x, pitch, delta * turn_speed)
	
	turret_body.scale = body_scale
	gun_pivot.scale = gun_scale

func _track_target(delta: float) -> void:
	var aim_pt = current_target.global_position + Vector3(0, aim_height_offset, 0)

	# 1. Rotate Body (Y Axis) - Flip 180 for Positive Z model
	var body_pos = aim_pt
	body_pos.y = turret_body.global_position.y
	var b_dir = (body_pos - turret_body.global_position).normalized()
	if !b_dir.is_zero_approx():
		var target_basis_y = Basis.looking_at(b_dir, Vector3.UP).rotated(Vector3.UP, PI)
		var cur_b_quat = turret_body.global_transform.basis.get_rotation_quaternion()
		turret_body.global_basis = Basis(cur_b_quat.slerp(target_basis_y.get_rotation_quaternion(), delta * turn_speed))
		turret_body.scale = body_scale

	# 2. Rotate Hinge (X Axis) - Flip 180 for Positive Z model
	var g_dir = (aim_pt - gun_pivot.global_position).normalized()
	if !g_dir.is_zero_approx():
		var target_basis_x = Basis.looking_at(g_dir, Vector3.UP).rotated(Vector3.UP, PI)
		var cur_g_quat = gun_pivot.global_transform.basis.get_rotation_quaternion()
		gun_pivot.global_basis = Basis(cur_g_quat.slerp(target_basis_x.get_rotation_quaternion(), delta * turn_speed))
		gun_pivot.scale = gun_scale

func _on_target_entered(body: Node3D) -> void:
	if body.is_in_group("enemies") and not targets.has(body):
		targets.append(body)

func _on_target_exited(body: Node3D) -> void:
	if targets.has(body):
		targets.erase(body)
