extends Label

func _ready():
	# 1. Fetch your game version from Project Settings
	var game_v = ProjectSettings.get_setting("application/config/version")
	
	# Fallback if the version field is empty in settings
	if game_v == "": 
		game_v = "0.0.0"
	
	# 2. Determine if this is a Debug or Release build
	var build_status = "DEBUG" if OS.is_debug_build() else "RELEASE"
	
	# 3. Format the final text
	# Results in: "v1.2.0 | DEBUG"
	text = "v%s | %s" % [game_v, build_status]
	
	# Optional: Slight transparency for a professional watermark look
	modulate.a = 0.6
