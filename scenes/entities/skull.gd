extends CharacterBody3D

enum State { IDLE, AGGRO }

@export_group("Movement")
@export var speed := 5.0
@export var acceleration := 2.0
@export var idle_drift_speed := 1.5

@export_group("Combat")
@export var melee_range := 2.0
@export var melee_damage := 10
@export var ranged_cooldown := 2.0
@export var attack_ray_length := 15.0

@export_group("Detection")
@export_node_path("Area3D") var detection_area_path
@onready var detection_area: Area3D = get_node(detection_area_path)
@export var switch_target_cooldown := 1.5 

@export_group("Sounds")
@export var idle_sound: AudioStream
@export var aggro_sound: AudioStream
@export var melee_attack_sound: AudioStream
@export var ranged_attack_sound: AudioStream
@onready var audio_player: AudioStreamPlayer3D = $AudioStreamPlayer3D

@onready var raycast: RayCast3D = $RayCast3D

@export_group("Visuals")
@export var skin_color: Color

# State with Setter to sync sounds/visuals across the network
var current_state = State.IDLE:
	set(value):
		if current_state != value:
			current_state = value
			if multiplayer.is_server():
				_sync_state_effects.rpc(current_state)

var target_player: Node3D = null
var players_in_range: Array[Node3D] = []
var idle_target_pos := Vector3.ZERO
var drift_timer := 0.0
var switch_timer := 0.0 
var attack_cooldown_timer := 0.0

func _ready():
	if not multiplayer.is_server(): return 
	
	_pick_new_idle_pos()
	
	if detection_area:
		detection_area.body_entered.connect(_on_detection_area_body_entered)
		detection_area.body_exited.connect(_on_detection_area_body_exited)

	# set the skin
	$OmniLight3D.light_color = skin_color
	
func _physics_process(delta):
	if not multiplayer.is_server(): return
	
	if switch_timer > 0: switch_timer -= delta
	if attack_cooldown_timer > 0: attack_cooldown_timer -= delta

	_update_target_logic()

	match current_state:
		State.IDLE:
			_process_idle(delta)
		State.AGGRO:
			_process_aggro(delta)
	
	_apply_bobbing(delta)
	move_and_slide()

## --- TARGETING LOGIC (Server Only) ---

func _update_target_logic():
	if players_in_range.is_empty():
		target_player = null
		current_state = State.IDLE
		return

	# Hysteresis: Stay locked on target unless timer out or they leave
	if target_player != null and switch_timer > 0:
		if is_instance_valid(target_player) and players_in_range.has(target_player):
			return

	var closest_dist := INF
	var closest_body: Node3D = null

	for player in players_in_range:
		if is_instance_valid(player):
			var dist = global_position.distance_to(player.global_position)
			if dist < closest_dist:
				closest_dist = dist
				closest_body = player
	
	if closest_body and closest_body != target_player:
		target_player = closest_body
		current_state = State.AGGRO
		switch_timer = switch_target_cooldown

## --- STATE LOGIC (Server Only) ---

func _process_idle(delta):
	drift_timer -= delta
	if drift_timer <= 0 or global_position.distance_to(idle_target_pos) < 1.0:
		_pick_new_idle_pos()

	var dir = (idle_target_pos - global_position).normalized()
	velocity = velocity.move_toward(dir * idle_drift_speed, acceleration * delta)
	_smooth_look_at(idle_target_pos, delta * 2.0)

func _process_aggro(delta):
	if not target_player:
		current_state = State.IDLE
		return

	var dist = global_position.distance_to(target_player.global_position)
	
	var dir = (target_player.global_position - global_position).normalized()
	velocity = velocity.move_toward(dir * speed, acceleration * delta)
	_smooth_look_at(target_player.global_position, delta * 6.0)

	if attack_cooldown_timer <= 0:
		if dist <= melee_range:
			_perform_melee_attack()
		else:
			_perform_ranged_check()

## --- COMBAT ACTIONS (Server Only) ---

func _perform_melee_attack():
	attack_cooldown_timer = ranged_cooldown
	_play_attack_effects.rpc("melee")
	if target_player.has_method("take_damage"):
		target_player.take_damage(melee_damage)

func _perform_ranged_check():
	var target_pos = target_player.global_position + Vector3(0, 1, 0)
	raycast.look_at(target_pos)
	raycast.target_position = Vector3(0, 0, -attack_ray_length)
	raycast.force_raycast_update()

	if raycast.is_colliding():
		var collider = raycast.get_collider()
		if collider == target_player:
			_perform_ranged_attack()

func _perform_ranged_attack():
	attack_cooldown_timer = ranged_cooldown
	_play_attack_effects.rpc("ranged")
	if target_player.has_method("take_damage"):
		target_player.take_damage(5)

## --- MULTIPLAYER SYNC (All Clients) ---

@rpc("authority", "call_local", "unreliable")
func _play_attack_effects(type: String):
	if type == "melee":
		audio_player.stream = melee_attack_sound
	elif type == "ranged":
		audio_player.stream = ranged_attack_sound
	
	if audio_player.stream:
		audio_player.play()

@rpc("authority", "call_local", "reliable")
func _sync_state_effects(new_state: State):
	match new_state:
		State.AGGRO:
			if aggro_sound:
				audio_player.stream = aggro_sound
				audio_player.play()
		State.IDLE:
			if idle_sound:
				audio_player.stream = idle_sound
				audio_player.play()
			else:
				audio_player.stop()

## --- SIGNAL CALLBACKS ---

func _on_detection_area_body_entered(body: Node3D):
	if not multiplayer.is_server(): return 
	if 'IS_PLAYER' in body and body.IS_PLAYER:
		if not players_in_range.has(body):
			players_in_range.append(body)

func _on_detection_area_body_exited(body: Node3D):
	if not multiplayer.is_server(): return 
	if players_in_range.has(body):
		players_in_range.erase(body)
		if body == target_player:
			switch_timer = 0 

## --- HELPERS ---

func _pick_new_idle_pos():
	idle_target_pos = global_position + Vector3(randf_range(-5, 5), randf_range(-2, 2), randf_range(-5, 5))
	drift_timer = randf_range(3.0, 6.0)

func _smooth_look_at(target_pos: Vector3, weight: float):
	if global_position.is_equal_approx(target_pos): return
	var look_transform = transform.looking_at(target_pos, Vector3.UP)
	transform = transform.interpolate_with(look_transform, weight)

func _apply_bobbing(delta):
	var bob = sin(Time.get_ticks_msec() * 0.003) * 0.2
	velocity.y += bob * delta
