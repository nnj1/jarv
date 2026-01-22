extends RigidBody3D

enum State { IDLE, AGGRO, ATTACK, STOMP, DEAD }

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
@export var stomp_duration := 1.2 / 2 
@export var revenge_duration := 10.0
@export var max_health := 1000.0 / 10
@export var current_health := max_health

@export_group("Detection")
@export var kill_plane_y := -2000.0
@export_node_path("Area3D") var detection_area_path
@onready var detection_area: Area3D = get_node(detection_area_path)
@onready var paw_hitbox: Area3D = $Area3D2

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

@onready var damage_marker = preload('res://scenes/damage_marker.tscn')
@onready var damage_marker_point =$damage_marker_point

const IS_ENEMY: bool = true

# --- STATE SETTER ---
var current_state = State.IDLE: 
	set(value):
		if current_state != value:
			current_state = value
			if anim_player:
				anim_player.speed_scale = 1.0 
			if is_inside_tree() and multiplayer.is_server():
				_sync_anim_speed.rpc(1.0)
				_update_state_assets(current_state)

# --- TARGETING VARIABLES ---
var target_node: Node3D = null      
var rv_target: Node3D = null        
var revenge_target: Node3D = null   
var revenge_timer := 0.0

var players_in_range: Array[Node3D] = []
var home_position := Vector3.ZERO
var wander_direction := Vector3.ZERO
var wander_timer := 0.0
var is_waiting := false
var attack_cooldown_timer := 0.0
var stomp_timer := 0.0
var last_sent_anim := ""

func _enter_tree() -> void:
	self.global_position = home_position + Vector3(0.01, 0.01, 0.01)

func _ready():
	#home_position = global_position
	contact_monitor = true
	max_contacts_reported = 10
	
	center_of_mass_mode = RigidBody3D.CENTER_OF_MASS_MODE_CUSTOM
	center_of_mass = Vector3(0, -1.0, 0) 
	
	if not multiplayer.is_server(): return 
	
	_update_wander_logic()
	if detection_area:
		detection_area.body_entered.connect(_on_detection_area_body_entered)
		detection_area.body_exited.connect(_on_detection_area_body_exited)
	
	self.body_entered.connect(_on_body_entered)

# --- ANIMATION CALLBACKS (Fixes Method Not Found Error) ---

func activate_paw_area():
	if paw_hitbox: paw_hitbox.monitoring = true

func deactivate_paw_area():
	if paw_hitbox: paw_hitbox.monitoring = false

# --- COMBAT & DAMAGE ---

@rpc("any_peer", "call_local", "reliable")
func show_damage_marker(amount: int):
	var marker = damage_marker.instantiate()
	marker.prepare(amount)
	damage_marker_point.add_child(marker)
	
@rpc("any_peer", "call_local", "reliable")
func damage(amount: int):
	if not multiplayer.is_server() or current_state == State.DEAD: return
	
	current_health = clamp(current_health - amount, 0, max_health)
	
	if current_health <= 0:
		current_state = State.DEAD
		return

	var attacker_id = multiplayer.get_remote_sender_id()
	for player in players_in_range:
		if is_instance_valid(player) and player.get_multiplayer_authority() == attacker_id:
			revenge_target = player
			revenge_timer = revenge_duration
			break

	if amount >= 25:
		current_state = State.STOMP
		stomp_timer = stomp_duration
		
	rpc('show_damage_marker', amount)

func _on_body_entered(body):
	if not multiplayer.is_server() or current_state == State.DEAD: return
	if (body.get("IS_PLAYER") or body.get("IS_RV")):
		if current_state != State.STOMP and attack_cooldown_timer <= 0:
			_perform_attack(body)

func _perform_attack(_target):
	current_state = State.ATTACK
	attack_cooldown_timer = attack_cooldown
	last_sent_anim = "" 
	
	anim_player.speed_scale = 1.0
	_sync_anim_speed.rpc(1.0)
	
	get_tree().create_timer(1.0).timeout.connect(func():
		if current_state == State.ATTACK:
			current_state = State.AGGRO
	)

# --- PROCESSING ---

func _physics_process(delta):
	if not multiplayer.is_server() or current_state == State.DEAD: return
	
	# --- VOID CHECK ---
	if global_position.y < kill_plane_y:
		damage(9999) # Instantly kill the bear
		return
		
	if attack_cooldown_timer > 0: 
		attack_cooldown_timer -= delta
	
	if revenge_timer > 0:
		revenge_timer -= delta
		if revenge_timer <= 0: revenge_target = null
	
	match current_state:
		State.STOMP:
			stomp_timer -= delta
			if stomp_timer <= 0: current_state = State.AGGRO
		State.IDLE:
			wander_timer -= delta
			if wander_timer <= 0: _update_wander_logic()
			if is_waiting: _play_anim_if_new("idleSmell")
			else: _play_anim_if_new("polarbearrun")
		State.AGGRO:
			_play_anim_if_new("polarbearrun")
			var horiz_vel = Vector3(linear_velocity.x, 0, linear_velocity.z).length()
			if horiz_vel > 0.5:
				var target_anim_speed = clamp(remap(horiz_vel, 0, max_speed, 0.4, 1.2), 0.4, 1.2)
				_sync_anim_speed.rpc(target_anim_speed)
			else:
				_sync_anim_speed.rpc(1.0)
			
			if target_node and attack_cooldown_timer <= 0:
				var bodies = get_colliding_bodies()
				if bodies.has(target_node):
					_perform_attack(target_node)

	if current_state != State.STOMP:
		_update_target_logic()
	
	if paw_hitbox.monitoring:
		for body in paw_hitbox.get_overlapping_bodies():
			if body.has_method('damage'):
				body.rpc('damage', int(delta * 100))

func _integrate_forces(state: PhysicsDirectBodyState3D):
	if not multiplayer.is_server(): return
	
	if current_state in [State.STOMP, State.ATTACK, State.DEAD]:
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
	elif current_state == State.AGGRO and target_node:
		move_dir = (target_node.global_position - global_position).normalized()

	if move_dir.length() > 0.1:
		var look_dir = Vector3(move_dir.x, 0, move_dir.z)
		var target_up = ground_normal if is_on_ground else Vector3.UP
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
		var horizontal_vel = Vector3(linear_velocity.x, 0, linear_velocity.z)
		apply_central_force(-horizontal_vel * stop_drag)

# --- ASSETS & NETWORKING ---

func _update_state_assets(new_state: State):
	match new_state:
		State.IDLE: _play_random_sound_rpc.rpc(State.IDLE)
		State.AGGRO: _play_random_sound_rpc.rpc(State.AGGRO)
		State.STOMP: 
			_play_anim_if_new("polarbearstomp")
			_play_random_sound_rpc.rpc(State.STOMP)
		State.ATTACK:
			_play_anim_if_new("attackDownRight")
			_play_random_sound_rpc.rpc(State.ATTACK)
		State.DEAD:
			_play_anim_if_new("death") 
			_play_random_sound_rpc.rpc(State.DEAD)
			_handle_death_cleanup()

func _handle_death_cleanup():
	set_physics_process(false)
	# players can no longer hit the bear
	collision_layer = 0
	# don't collide with player
	set_collision_mask_value(3, false)
	set_collision_mask_value(4, false)
	
	# Let it fall and settle, then freeze
	get_tree().create_timer(2.0).timeout.connect(func():
		freeze = true 
	)
	
	deactivate_paw_area()
	
	# TODO: could spawn drops here
	# clean up
	get_tree().create_timer(60.0).timeout.connect(queue_free)

func _play_anim_if_new(anim_name: String):
	if last_sent_anim != anim_name:
		last_sent_anim = anim_name
		_play_anim_rpc.rpc(anim_name)

@rpc("authority", "call_local", "unreliable")
func _play_anim_rpc(anim_name: String):
	if anim_player.has_animation(anim_name):
		anim_player.play(anim_name)

@rpc("authority", "call_local", "unreliable")
func _play_random_sound_rpc(state_for_sound: State):
	var pool: Array[AudioStream] = []
	match state_for_sound:
		State.IDLE: pool = idle_sounds
		State.AGGRO: pool = aggro_sounds
		State.STOMP, State.DEAD: pool = hurt_sounds
		State.ATTACK: pool = attack_sounds
	
	if not pool.is_empty():
		audio_player.stream = pool.pick_random()
		audio_player.play()

@rpc("authority", "call_local", "unreliable")
func _sync_anim_speed(speed: float):
	if anim_player:
		anim_player.speed_scale = speed

# --- AI UTILS ---

func _update_wander_logic():
	if current_state == State.DEAD: return
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
	if current_state == State.DEAD: return
	players_in_range = players_in_range.filter(func(p): return is_instance_valid(p))
	
	var next_target: Node3D = null
	if revenge_target: next_target = revenge_target
	elif rv_target: next_target = rv_target
	elif not players_in_range.is_empty():
		var closest_dist := INF
		for player in players_in_range:
			var dist = global_position.distance_to(player.global_position)
			if dist < closest_dist:
				closest_dist = dist
				next_target = player

	target_node = next_target
	if target_node:
		if current_state == State.IDLE: current_state = State.AGGRO
	else:
		if current_state == State.AGGRO: current_state = State.IDLE

func _on_detection_area_body_entered(body):
	if body.get("IS_RV"): rv_target = body
	if body.get("IS_PLAYER") and not players_in_range.has(body):
		players_in_range.append(body)

func _on_detection_area_body_exited(body):
	if body == rv_target: rv_target = null
	if players_in_range.has(body): players_in_range.erase(body)
