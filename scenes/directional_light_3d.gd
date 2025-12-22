extends DirectionalLight3D

@export var day_speed: float = 0.05
@export var sun_color: Color = Color("fff5f2")
@export var sunset_color: Color = Color("ffad64")

var time: float = 0.0

func _process(delta):
	time += delta * day_speed
	
	# Rotate the sun. Wrap the value so it stays between 0 and 2*PI (360 degrees)
	rotation.x = fmod(time, TAU) 
	
	# Adjust intensity based on the angle of the sun
	# rotation.x > 0 and < PI means the sun is below the horizon
	var sun_height = sin(rotation.x)
	
	if sun_height < 0:
		# Day time (Sun is up)
		light_intensity_lumens = abs(sun_height) * 10.0
		# Interpolate color for a sunset effect
		light_color = sunset_color.lerp(sun_color, abs(sun_height))
		
		
	else:
		# Night time (Sun is down)
		light_intensity_lumens = 0.0
	
	if sun_height < 0:
			# SUN IS UP
			sky_mode = DirectionalLight3D.SKY_MODE_LIGHT_AND_SKY
			light_intensity_lumens = abs(sun_height) * 10.0
	else:
		# SUN IS DOWN (Night)
		# Switching to LIGHT_ONLY removes the "orange horizon" effect
		sky_mode = DirectionalLight3D.SKY_MODE_LIGHT_ONLY
		light_intensity_lumens = 0.0
