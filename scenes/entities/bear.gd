extends RigidBody3D

enum State { IDLE, AGGRO }

@export_group("Movement")
@export var move_force := 5500.0
@export var max_speed := 8.0
@export var stop_drag := 15.0
@export var turn_speed := 5.0
@export var gravity_glue := 1000.0 # Increased to keep paws on slopes

@export_group("Wander Settings")
@export var wander_interval_min := 3.0
@export var wander_interval_max := 6.0
@export var wander_speed_multiplier := 0.4
@export var max_wander_distance := 15.0 

@export_group("Combat")
@export var melee_range := 3.0
@export var melee_damage := 25
@export var attack_cooldown := 1.5

@export_group("Detection")
@export_node_path("Area3D") var detection_area_path
@onready var detection_area: Area3D = get_node(detection_area_path)

@export_group("Sounds")
@export var idle_sound: AudioStream
@export var aggro_sound: AudioStream
@export var melee_attack_sound: AudioStream
@onready var audio_player: AudioStreamPlayer3D = $AudioStreamPlayer3D

@onready var anim_player: AnimationPlayer = $Sketchfab_Scene/AnimationPlayer

const IS_ENEMY: bool = true

var current_state = State.IDLE: set = set_current_state

var target_player: Node3D = null
var players_in_range: Array[Node3D] = []
var home_position := Vector3.ZERO

var wander_direction := Vector3.ZERO
var wander_timer := 0.0
var is_waiting := false
var attack_cooldown_timer := 0.0

func _ready():
	contact_monitor = true
	max_contacts_reported = 4
	
	# IMPORTANT: We do NOT lock X and Z axes here anymore. 
	# We want the bear to tilt with the slope!
	
	center_of_mass_mode = RigidBody3D.CENTER_OF_MASS_MODE_CUSTOM
	center_of_mass = Vector3(0, -1.0, 0) 
	
	# FIX: Initialize home position
	home_position = global_position
	
	if not multiplayer.is_server(): return 
	_update_wander_logic()
	
	if detection_area:
		detection_area.body_entered.connect(_on_detection_area_body_entered)
		detection_area.body_exited.connect(_on_detection_area_body_exited)

func set_current_state(value):
	if current_state != value:
		current_state = value
		if is_inside_tree() and multiplayer.is_server():
			_sync_state_sounds.rpc(current_state)

func _physics_process(delta):
	if not multiplayer.is_server(): return
	
	if attack_cooldown_timer > 0: attack_cooldown_timer -= delta
	
	if current_state == State.IDLE:
		wander_timer -= delta
		if wander_timer <= 0:
			_update_wander_logic()
			
	_update_target_logic()
	
	# DYNAMIC ANIMATION SPEED
	var horizontal_vel = Vector3(linear_velocity.x, 0, linear_velocity.z)
	var speed_magnitude = horizontal_vel.length()
	var target_anim_speed = 1.0
	if speed_magnitude > 0.1:
		target_anim_speed = remap(speed_magnitude, 0, max_speed, 0.01, 1.0)
	
	_sync_anim_speed.rpc(target_anim_speed)

func _integrate_forces(state: PhysicsDirectBodyState3D):
	if not multiplayer.is_server(): return
	
	# 1. GROUND DETECTION
	var ground_normal = Vector3.UP
	var is_on_ground = false
	var space_state = get_world_3d().direct_space_state
	
	var ray_origin = global_position + Vector3.UP * 0.5
	var ray_end = global_position + Vector3.DOWN * 2.5 # Deep ray to find ground
	var query = PhysicsRayQueryParameters3D.create(ray_origin, ray_end)
	query.exclude = [get_rid()]
	var result = space_state.intersect_ray(query)
	
	if result:
		ground_normal = result.normal
		is_on_ground = true

	# 2. DIRECTION LOGIC
	var move_dir = Vector3.ZERO
	var current_max_speed = max_speed

	match current_state:
		State.IDLE:
			if not is_waiting:
				move_dir = wander_direction
				current_max_speed = max_speed * wander_speed_multiplier
		State.AGGRO:
			if target_player:
				var to_target = (target_player.global_position - global_position)
				move_dir = to_target.normalized()
				_check_attack(to_target.length())

	# 3. SLOPE-AWARE ROTATION
	if move_dir.length() > 0.1:
		var look_dir = Vector3(move_dir.x, 0, move_dir.z)
		
		# Align the "Up" vector to the ground normal so the bear tilts
		var target_up = ground_normal if is_on_ground else Vector3.UP
		var target_basis = Basis.looking_at(look_dir, target_up)
		
		# Slerp provides the stability that Axis Locks used to provide
		state.transform.basis = state.transform.basis.slerp(target_basis, turn_speed * state.step).orthonormalized()
	elif is_on_ground:
		# Keep current tilt even when standing still
		var current_fwd = -state.transform.basis.z
		var target_basis = Basis.looking_at(Vector3(current_fwd.x, 0, current_fwd.z), ground_normal)
		state.transform.basis = state.transform.basis.slerp(target_basis, turn_speed * state.step).orthonormalized()

	# 4. MOVEMENT & GRAVITY GLUE
	var current_vel = linear_velocity
	var horizontal_speed = Vector3(current_vel.x, 0, current_vel.z).length()
	
	if is_on_ground:
		# Pushes bear into the slope based on the ground's angle
		apply_central_force(-ground_normal * gravity_glue)
		
		if move_dir.length() > 0.1:
			_play_anim_rpc.rpc("polarbearrun")
			
			var right_vec = move_dir.cross(Vector3.UP)
			var slope_dir = ground_normal.cross(right_vec).normalized()
			
			if horizontal_speed < current_max_speed:
				apply_central_force(slope_dir * move_force)
		else:
			_play_anim_rpc.rpc("idleSmell")
			# Apply friction-like force to prevent sliding down hills
			apply_central_force(-Vector3(current_vel.x, 0, current_vel.z) * stop_drag)
	else:
		# Falling animation or logic could go here
		pass

## --- AI & NETWORKING ---

func _update_wander_logic():
	is_waiting = randf() < 0.4
	if is_waiting:
		wander_direction = Vector3.ZERO
		wander_timer = randf_range(2.0, 4.0)
	else:
		var random_angle = randf() * TAU
		var new_dir = Vector3(cos(random_angle), 0, sin(random_angle))
		
		if global_position.distance_to(home_position) > max_wander_distance:
			wander_direction = (home_position - global_position).normalized()
		else:
			wander_direction = new_dir
			
		wander_timer = randf_range(wander_interval_min, wander_interval_max)

func _update_target_logic():
	if players_in_range.is_empty():
		target_player = null
		current_state = State.IDLE
		return
	
	var closest_dist := INF
	var closest_player: Node3D = null
	for player in players_in_range:
		if is_instance_valid(player):
			var dist = global_position.distance_to(player.global_position)
			if dist < closest_dist:
				closest_dist = dist
				closest_player = player
	
	if closest_player:
		target_player = closest_player
		current_state = State.AGGRO

func _check_attack(dist: float):
	if attack_cooldown_timer <= 0 and dist <= melee_range:
		attack_cooldown_timer = attack_cooldown
		_play_attack_effects.rpc()
		if target_player.has_method("take_damage"):
			target_player.take_damage(melee_damage)

@rpc("authority", "call_local", "reliable")
func _sync_state_sounds(new_state: State):
	match new_state:
		State.AGGRO:
			if aggro_sound:
				audio_player.stream = aggro_sound
				audio_player.play()
		State.IDLE:
			if idle_sound:
				audio_player.stream = idle_sound
				audio_player.play()

@rpc("authority", "call_local", "unreliable")
func _sync_anim_speed(speed: float):
	anim_player.speed_scale = speed

@rpc("authority", "call_local", "unreliable")
func _play_anim_rpc(anim_name: String):
	if anim_player.current_animation != anim_name:
		anim_player.play(anim_name)

@rpc("authority", "call_local", "unreliable")
func _play_attack_effects():
	audio_player.stream = melee_attack_sound
	audio_player.play()

func _on_detection_area_body_entered(body):
	if 'IS_PLAYER' in body and body.IS_PLAYER:
		if not players_in_range.has(body):
			players_in_range.append(body)

func _on_detection_area_body_exited(body):
	if players_in_range.has(body):
		players_in_range.erase(body)
