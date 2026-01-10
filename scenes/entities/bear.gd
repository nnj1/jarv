extends RigidBody3D

enum State { IDLE, AGGRO, ATTACK, STOMP }

@export_group("Movement")
@export var move_force := 5500.0
@export var max_speed := 16.0
@export var stop_drag := 15.0
@export var turn_speed := 5.0
@export var gravity_glue := 1000.0 

@export_group("Wander Settings")
@export var wander_interval_min := 3.0
@export var wander_interval_max := 6.0
@export var wander_speed_multiplier := 0.4 
@export var max_wander_distance := 15.0 

@export_group("Combat")
@export var melee_damage := 25
@export var attack_cooldown := 1.5
@export var stomp_duration := 1.2

@export_group("Detection")
@export_node_path("Area3D") var detection_area_path
@onready var detection_area: Area3D = get_node(detection_area_path)

@export_group("Sounds")
@export var idle_sounds: Array[AudioStream] = [
	preload('res://assets/Beasts/Beasts/Beast_Bellow1.wav'),
	preload('res://assets/Beasts/Beasts/Beast_Bellow2.wav'),
	preload('res://assets/Beasts/Beasts/Beast_Bellow3.wav'),
	preload('res://assets/Beasts/Beasts/Beast_Bellow4.wav'),
	preload('res://assets/Beasts/Beasts/Beast_Bellow5.wav'),
	preload('res://assets/Beasts/Beasts/Beast_Bellow6.wav'),
	preload('res://assets/Beasts/Beasts/Beast_Bellow7.wav'),
	preload('res://assets/Beasts/Beasts/Beast_Bellow8.wav'),
	preload('res://assets/Beasts/Beasts/Beast_Bellow9.wav'),
	preload('res://assets/Beasts/Beasts/Beast_Bellow10.wav'),
	preload('res://assets/Beasts/Beasts/Beast_Bellow11.wav'),
	preload('res://assets/Beasts/Beasts/Beast_Bellow12.wav'),
	preload('res://assets/Beasts/Beasts/Beast_Bellow13.wav'),
	preload('res://assets/Beasts/Beasts/Beast_Bellow14.wav')
]
@export var aggro_sounds: Array[AudioStream] = [
	preload('res://assets/Beasts/Beasts/Beast_Growl.wav'),
	preload('res://assets/Beasts/Beasts/Beast_Growl1.wav'),
	preload('res://assets/Beasts/Beasts/Beast_Growl2.wav'),
	preload('res://assets/Beasts/Beasts/Beast_Growl3.wav'),
	preload('res://assets/Beasts/Beasts/Beast_Growl4.wav'),
	preload('res://assets/Beasts/Beasts/Beast_Growl5.wav')
]
@export var attack_sounds: Array[AudioStream] = [
	preload('res://assets/Beasts/Beasts/Beast_Grunt.wav'),
	preload('res://assets/Beasts/Beasts/Beast_Grunt2.wav'),
	preload('res://assets/Beasts/Beasts/Beast_Grunt3.wav'),
	preload('res://assets/Beasts/Beasts/Beast_Grunt4.wav'),
	preload('res://assets/Beasts/Beasts/Beast_Grunt5.wav'),
]
@export var hurt_sounds: Array[AudioStream] = [
	preload('res://assets/Beasts/Beasts/Beast_Roar.wav'),
]
@onready var audio_player: AudioStreamPlayer3D = $AudioStreamPlayer3D

@onready var anim_player: AnimationPlayer = $Sketchfab_Scene/AnimationPlayer

const IS_ENEMY: bool = true

# --- STATE SETTER ---
var current_state = State.IDLE: 
	set(value):
		if current_state != value:
			current_state = value
			if is_inside_tree() and multiplayer.is_server():
				_update_state_assets(current_state)

var target_player: Node3D = null
var players_in_range: Array[Node3D] = []
var home_position := Vector3.ZERO
var wander_direction := Vector3.ZERO
var wander_timer := 0.0
var is_waiting := false
var attack_cooldown_timer := 0.0
var stomp_timer := 0.0

func _ready():
	contact_monitor = true
	max_contacts_reported = 4
	center_of_mass_mode = RigidBody3D.CENTER_OF_MASS_MODE_CUSTOM
	center_of_mass = Vector3(0, -1.0, 0) 
	
	if not multiplayer.is_server(): return 
	
	_update_wander_logic()
	if detection_area:
		detection_area.body_entered.connect(_on_detection_area_body_entered)
		detection_area.body_exited.connect(_on_detection_area_body_exited)
	
	self.body_entered.connect(_on_body_entered)

# --- COMBAT & DAMAGE ---
@rpc("any_peer", "call_local", "reliable")
func damage(amount: int):
	if not multiplayer.is_server(): return
	# only change to stomp state if the damage is above a treshold
	if amount >= 25:
		current_state = State.STOMP
		stomp_timer = stomp_duration

func _on_body_entered(body):
	if not multiplayer.is_server(): return
	if 'IS_PLAYER' in body and body.IS_PLAYER:
		if current_state != State.STOMP and attack_cooldown_timer <= 0:
			_perform_attack(body)

func _perform_attack(_player):
	current_state = State.ATTACK
	attack_cooldown_timer = attack_cooldown
	
	# leave this state after a while
	get_tree().create_timer(1.0).timeout.connect(func():
		if current_state == State.ATTACK:
			current_state = State.AGGRO
	)
	
func activate_paw_area():
	$Area3D2.monitoring = true

func deactivate_paw_area():
	$Area3D2.monitoring = false

# --- PROCESSING ---

func _physics_process(delta):
	if not multiplayer.is_server(): return
	
	if attack_cooldown_timer > 0: 
		attack_cooldown_timer -= delta
	
	match current_state:
		State.STOMP:
			stomp_timer -= delta
			if stomp_timer <= 0:
				current_state = State.AGGRO
		State.IDLE:
			wander_timer -= delta
			if wander_timer <= 0:
				_update_wander_logic()
			
			if is_waiting:
				_play_anim_rpc.rpc("idleSmell")
			else:
				_play_anim_rpc.rpc("polarbearrun")
				
		State.AGGRO:
			_play_anim_rpc.rpc("polarbearrun")
	
	if current_state != State.STOMP:
		_update_target_logic()
	
	# adjust speed of animations
	if current_state == State.AGGRO: 
		var horiz_vel = Vector3(linear_velocity.x, 0, linear_velocity.z).length()
		var target_anim_speed = clamp(remap(horiz_vel, 0, max_speed, 0.1, 1.0), 0.1, 1.0)
		_sync_anim_speed.rpc(target_anim_speed)

	# damage anything in paw area
	if $Area3D2.monitoring:
		for body in $Area3D2.get_overlapping_bodies():
			if body.has_method('damage'):
				body.rpc('damage', delta * 100)
		
	
func _integrate_forces(state: PhysicsDirectBodyState3D):
	if not multiplayer.is_server(): return
	
	if current_state == State.STOMP or current_state == State.ATTACK:
		state.linear_velocity.x = lerp(state.linear_velocity.x, 0.0, stop_drag * state.step)
		state.linear_velocity.z = lerp(state.linear_velocity.z, 0.0, stop_drag * state.step)
		return

	var ground_normal = Vector3.UP
	var is_on_ground = false
	var space_state = get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create(global_position + Vector3.UP, global_position + Vector3.DOWN * 2.0)
	query.exclude = [get_rid()]
	var result = space_state.intersect_ray(query)
	if result:
		ground_normal = result.normal
		is_on_ground = true

	var move_dir = Vector3.ZERO
	var current_max_speed = max_speed
	if current_state == State.IDLE and not is_waiting:
		move_dir = wander_direction
		current_max_speed = max_speed * wander_speed_multiplier
	elif current_state == State.AGGRO and target_player:
		move_dir = (target_player.global_position - global_position).normalized()

	if move_dir.length() > 0.1:
		var look_dir = Vector3(move_dir.x, 0, move_dir.z)
		var target_up = ground_normal if is_on_ground else Vector3.UP
		if look_dir.cross(target_up).length() > 0.001:
			var target_basis = Basis.looking_at(look_dir, target_up)
			state.transform.basis = state.transform.basis.slerp(target_basis, turn_speed * state.step).orthonormalized()
		
		state.angular_velocity = Vector3.ZERO 
		
		if is_on_ground:
			apply_central_force(-ground_normal * gravity_glue)
			var right_vec = move_dir.cross(Vector3.UP)
			var slope_dir = ground_normal.cross(right_vec).normalized()
			if Vector3(linear_velocity.x, 0, linear_velocity.z).length() < current_max_speed:
				apply_central_force(slope_dir * move_force)
	elif is_on_ground:
		apply_central_force(-Vector3(linear_velocity.x, 0, linear_velocity.z) * stop_drag)

# --- ASSETS & NETWORKING ---

func _update_state_assets(new_state: State):
	# The server decides which logic to trigger
	match new_state:
		State.IDLE: 
			if not idle_sounds.is_empty(): _play_random_sound_rpc.rpc(State.IDLE)
		State.AGGRO: 
			if not aggro_sounds.is_empty(): _play_random_sound_rpc.rpc(State.AGGRO)
		State.STOMP: 
			_play_anim_rpc.rpc("polarbearstomp")
			if not hurt_sounds.is_empty(): _play_random_sound_rpc.rpc(State.STOMP)
		State.ATTACK:
			_play_anim_rpc.rpc("attackDownRight")
			if not attack_sounds.is_empty(): _play_random_sound_rpc.rpc(State.ATTACK)

@rpc("authority", "call_local", "unreliable")
func _play_anim_rpc(anim_name: String):
	if not anim_player.has_animation(anim_name): return
	if anim_player.current_animation == anim_name and anim_player.is_playing(): return
	anim_player.play(anim_name)

@rpc("authority", "call_local", "unreliable")
func _play_random_sound_rpc(state_for_sound: State):
	var selected_sound: AudioStream = null
	
	match state_for_sound:
		State.IDLE: selected_sound = idle_sounds.pick_random()
		State.AGGRO: selected_sound = aggro_sounds.pick_random()
		State.STOMP: selected_sound = hurt_sounds.pick_random()
		State.ATTACK: selected_sound = attack_sounds.pick_random()
	
	if selected_sound:
		audio_player.stream = selected_sound
		audio_player.play()

@rpc("authority", "call_local", "unreliable")
func _sync_anim_speed(speed: float):
	anim_player.speed_scale = speed

# --- AI UTILS ---

func _update_wander_logic():
	is_waiting = randf() < 0.4
	if is_waiting:
		wander_direction = Vector3.ZERO
		wander_timer = randf_range(2.0, 4.0)
	else:
		var random_angle = randf() * TAU
		wander_direction = Vector3(cos(random_angle), 0, sin(random_angle))
		if global_position.distance_to(home_position) > max_wander_distance:
			wander_direction = (home_position - global_position).normalized()
		wander_timer = randf_range(wander_interval_min, wander_interval_max)

func _update_target_logic():
	if players_in_range.is_empty():
		target_player = null
		if current_state == State.AGGRO: current_state = State.IDLE
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
		if current_state == State.IDLE: current_state = State.AGGRO

func _on_detection_area_body_entered(body):
	if 'IS_PLAYER' in body and body.IS_PLAYER:
		if not players_in_range.has(body): players_in_range.append(body)

func _on_detection_area_body_exited(body):
	if players_in_range.has(body): players_in_range.erase(body)
