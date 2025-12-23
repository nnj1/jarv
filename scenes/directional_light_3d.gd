extends DirectionalLight3D

@export var day_speed: float = 0.05
@export var sun_color: Color = Color("fff5f2")
@export var sunset_color: Color = Color("ffad64")

var time: float = 0

func _process(delta):
	time += delta * day_speed
	
	# FIX 1: Use TAU (2 * PI) instead of 0. TAU represents a full 360-degree circle.
	rotation.x = fmod(time, TAU) 
	
	# FIX 2: Prevent gimbal lock/infinite math by ensuring the light 
	# is never pointing PERFECTLY straight down (90 degrees).
	# We add a tiny bit of Y and Z rotation so the matrix is always stable.
	rotation.y = deg_to_rad(10.0) 
	rotation.z = deg_to_rad(0.01)

	# Adjust intensity based on the angle of the sun
	var sun_height = sin(rotation.x)
	
	# Note: In Godot's default rotation, sin(rotation.x) < 0 usually means 
	# the light is pointing downward (Daytime).
	if sun_height < 0:
		# Day time (Sun is up)
		sky_mode = DirectionalLight3D.SKY_MODE_LIGHT_AND_SKY
		
		# Use clamp to ensure intensity doesn't accidentally hit NaN/Inf
		var intensity_factor = clamp(abs(sun_height), 0.0, 1.0)
		light_intensity_lumens = intensity_factor * 10.0
		
		# Interpolate color for a sunset effect
		light_color = sunset_color.lerp(sun_color, intensity_factor)
	else:
		# Night time (Sun is down)
		sky_mode = DirectionalLight3D.SKY_MODE_LIGHT_ONLY
		light_intensity_lumens = 0.0
