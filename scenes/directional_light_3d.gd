extends DirectionalLight3D

@export_group("Time Settings")
## Total real-world seconds for a full 24-hour cycle
@export var day_length_seconds: float = 60.0 
## The starting hour (0 to 24)
@export_range(0, 24) var current_hour: float = 12.0
## The seasonal tilt of the sun's path (in degrees)
@export var tilt_angle: float = 25.0 

@export_group("Nodes")
@export var world_env: WorldEnvironment

@export_group("Sky Colors")
@export var day_top_color: Color = Color("4b738c")
@export var day_horizon_color: Color = Color("a5a7ab")
@export var sunset_color: Color = Color("ffad64")
@export var night_top_color: Color = Color("050505")
@export var night_horizon_color: Color = Color("1a1a2e")

func _process(delta: float) -> void:
	# 1. Advance the clock
	var hours_per_second = 24.0 / day_length_seconds
	current_hour = fmod(current_hour + (delta * hours_per_second), 24.0)
	
	# 2. Map Hour to Rotation (0-24 maps to 0-TAU)
	# We offset by TAU * 0.25 (90 degrees) so 12:00 PM is directly overhead
	var time_percent = current_hour / 24.0
	var angle = (time_percent * TAU) - (TAU * 0.25)
	
	# 3. Apply rotation with tilt
	rotation = Vector3(angle, deg_to_rad(tilt_angle), 0)
	
	# 4. Update Atmosphere and Light
	update_visuals()

func update_visuals() -> void:
	if not world_env:
		return
		
	var sky_mat = world_env.environment.sky.sky_material as ProceduralSkyMaterial
	if not sky_mat:
		return

	# We use the Basis to find the vertical direction the light is facing.
	# transform.basis.z.y < 0 means the light is pointing down (Daytime)
	var sun_direction = transform.basis.z.y 
	
	if sun_direction < 0: # --- DAY & SUNSET ---
		# t is 1.0 at noon, 0.0 at horizon
		var t = clamp(abs(sun_direction), 0.0, 1.0)
		
		# Set Light properties
		light_energy = t * 2.0
		light_color = sunset_color.lerp(Color.WHITE, t)
		
		# Update Sky Material
		sky_mat.sky_top_color = night_top_color.lerp(day_top_color, t)
		sky_mat.sky_horizon_color = sunset_color.lerp(day_horizon_color, t)
		
		# Update Environment Brightness
		world_env.environment.background_energy_multiplier = lerp(0.1, 1.0, t)
		world_env.environment.ambient_light_energy = lerp(0.2, 1.0, t)
		
	else: # --- NIGHT ---
		# Turn off sun light, keep sky at base night colors
		light_energy = 0.0
		sky_mat.sky_top_color = night_top_color
		sky_mat.sky_horizon_color = night_horizon_color
		
		# Keep night visible but dark
		world_env.environment.background_energy_multiplier = 0.1
		world_env.environment.ambient_light_energy = 0.2

## Optional: Helper function to get a formatted time string (HH:MM)
func get_time_string() -> String:
	var hours = int(current_hour)
	var minutes = int((current_hour - hours) * 60)
	return "%02d:%02d" % [hours, minutes]

func get_time_12h(time_float = current_hour) -> String:
	var total_time = fmod(time_float, 24.0)
	var hours = int(total_time)
	var minutes = int((total_time - hours) * 60)
	
	var am_pm = "AM" if hours < 12 else "PM"
	
	# Convert 0 to 12, and 13-23 to 1-11
	var display_hours = hours % 12
	if display_hours == 0:
		display_hours = 12
		
	return "%d:%02d %s" % [display_hours, minutes, am_pm]
