extends CharacterBody3D

@export var speed: float = 500.0
@export var acceleration: float = 100.0
@export var lifetime: float = 5.0
@export var explosion_lifetime: float = 5
@export var damage_amount: int = 50

var current_speed: float = 0.0
var is_active: bool = true

@onready var mesh = $MeshInstance3D
@onready var collision_shape = $CollisionShape3D
@onready var explosion_particles = $explosion
@onready var explosion_sound = $AudioStreamPlayer3D
@onready var explosion_area = $Area3D

func _ready():
	# Set a timer to free the rocket if it doesn't hit anything
	await get_tree().create_timer(lifetime).timeout
	if is_active:
		explode()

func _physics_process(delta: float):
	if not is_active:
		return

	# Accelerate the rocket forward
	current_speed = move_toward(current_speed, speed, acceleration * delta)
	
	# Move toward positive Z (as per your specific setup)
	velocity = -transform.basis.z * current_speed
	
	# Move and check for collisions
	var collision = move_and_collide(velocity * delta)
	
	# IMPORTANT: Only the server handles the 'death' of the node
	if multiplayer.is_server():
		if collision:
			handle_collision(collision)

@warning_ignore("unused_parameter")
func handle_collision(collision: KinematicCollision3D):
	explode()

func explode():
	# We call an RPC so clients see the explosion too
	sync_explode.rpc()

@rpc("any_peer", "call_local", "reliable")
func sync_explode():
	if not is_active: return
	is_active = false
	
	# 1. Visuals and Sound (All Peers)
	mesh.hide()
	$fire.emitting = false
	
	var tween = create_tween()
	# Change "energy" to target_value (e.g., 5.0) over 0.25 seconds
	tween.tween_property($OmniLight3D, "light_energy", 10.0, 0.25)
	# Optional: Chain a second tween to fade it back down immediately
	tween.tween_property($OmniLight3D, "light_energy", 0.0, 0.25)
	
	explosion_particles.emitting = true
	$smoke.emitting = false
	explosion_sound.play()
	
	# 2. Physics (All Peers)
	collision_shape.set_deferred("disabled", true)
	
	# 3. Damage (Only Server)
	if multiplayer.is_server():
		var bodies = explosion_area.get_overlapping_bodies()
		for body in bodies:
			if body == self: continue
			if body.has_method("take_damage"):
				# Simple radial damage math
				var dist = global_position.distance_to(body.global_position)
				var radius = explosion_area.get_child(0).shape.radius
				var damage_multiplier = clamp(1.0 - (dist / radius), 0.0, 1.0)
				
				body.take_damage(int(damage_amount * damage_multiplier))
	
	# 4. Cleanup
	await get_tree().create_timer(explosion_lifetime).timeout
	queue_free()
