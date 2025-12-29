extends CharacterBody3D

enum State { IDLE, AGGRO }

@export_group("Movement")
@export var speed := 5.0
@export var acceleration := 2.0
@export var idle_drift_speed := 1.5

@export_node_path("Area3D") var detection_area_path
@onready var detection_area: Area3D = get_node(detection_area_path)

var current_state = State.IDLE
var target_player: Node3D = null
var idle_target_pos := Vector3.ZERO
var drift_timer := 0.0

func _ready():
	_pick_new_idle_pos()
	
	# Connect the Area3D signals
	if detection_area:
		detection_area.body_entered.connect(_on_detection_area_body_entered)
		detection_area.body_exited.connect(_on_detection_area_body_exited)
	else:
		push_warning("DetectionArea not assigned to Flying Skull!")

func _physics_process(delta):
	match current_state:
		State.IDLE:
			_process_idle(delta)
		State.AGGRO:
			_process_aggro(delta)
	
	_apply_bobbing(delta)
	move_and_slide()

## --- SIGNAL CALLBACKS ---

func _on_detection_area_body_entered(body: Node3D):
	# Check if the body entering is the player (ensure player is in "player" group)
	if body.is_in_group("player"):
		target_player = body
		current_state = State.AGGRO

func _on_detection_area_body_exited(body: Node3D):
	if body == target_player:
		target_player = null
		current_state = State.IDLE
		_pick_new_idle_pos() # Start drifting from where we lost them

## --- STATE LOGIC ---

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

	var dir = (target_player.global_position - global_position).normalized()
	velocity = velocity.move_toward(dir * speed, acceleration * delta)
	_smooth_look_at(target_player.global_position, delta * 6.0)

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
