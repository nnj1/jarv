extends CharacterBody3D

@export var speed: float = 500.0
@export var acceleration: float = 100.0
@export var lifetime: float = 5.0

var current_speed: float = 0.0

func _ready():
	# Set a timer to free the rocket if it doesn't hit anything
	await get_tree().create_timer(lifetime).timeout
	explode()

func _physics_process(delta: float):
	# Accelerate the rocket forward
	current_speed = move_toward(current_speed, speed, acceleration * delta)
	
	# transform.basis.z is "backwards" in Godot 3D, 
	# so we move toward positive Z (forward) (usually it's negative but I fucked this game up)
	velocity = -transform.basis.z * current_speed
	
	# Move and check for collisions
	var collision = move_and_collide(velocity * delta)
	
	if collision:
		handle_collision(collision)

@warning_ignore("unused_parameter")
func handle_collision(collision: KinematicCollision3D):
	# collision.get_collider() tells you what you hit
	# collision.get_position() tells you exactly where the spark/explosion should be
	explode()

func explode():
	# Instance your explosion scene here
	# var explosion = explosion_scene.instantiate()
	# get_parent().add_child(explosion)
	# explosion.global_position = global_position
	
	queue_free()
