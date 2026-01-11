extends OptionButton

# 1. Define available resolutions
# Using Vector2i (Integer vectors) as required for window sizing
var resolutions: Dictionary = {
	"1152x648 (DEBUG)": Vector2i(1152, 648),
	"1280x720 (HD)": Vector2i(1280, 720),
	"1600x900": Vector2i(1600, 900),
	"1920x1080 (FHD)": Vector2i(1920, 1080),
	"2560x1440 (QHD)": Vector2i(2560, 1440),
	"3840x2160 (4K)": Vector2i(3840, 2160)
}

func _ready() -> void:
	_populate_options()
	_select_current_window_res()
	
	# Connect the built-in signal to our function
	item_selected.connect(_on_resolution_selected)

func _populate_options() -> void:
	clear()
	for res_text in resolutions:
		add_item(res_text)

func _select_current_window_res() -> void:
	# Get the actual current size of the game window
	var current_res = DisplayServer.window_get_size()
	
	# Loop through items to see if one matches the current window size
	for i in range(item_count):
		var res_name = get_item_text(i)
		if resolutions[res_name] == current_res:
			select(i)
			return

func _on_resolution_selected(index: int) -> void:
	# Get the text of the selected option
	var res_name = get_item_text(index)
	# Find the corresponding Vector2i in our dictionary
	var target_res = resolutions[res_name]
	
	# Apply the resolution
	DisplayServer.window_set_size(target_res)
	
	# Center the window on the user's screen
	_center_window()

func _center_window() -> void:
	var screen_id = DisplayServer.window_get_current_screen()
	var screen_rect = DisplayServer.screen_get_usable_rect(screen_id)
	var window_size = DisplayServer.window_get_size()
	
	# Simple math to find the center point
	var center_pos = screen_rect.position + (screen_rect.size / 2) - (window_size / 2)
	DisplayServer.window_set_position(center_pos)
