extends Node

# Preload your cursor assets for better performance
var default_cursor = preload("res://assets/kenney_cursor-pack/PNG/Outline/Default/pointer_b_shaded.png")
var interactive_cursor = preload("res://assets/kenney_cursor-pack/PNG/Outline/Default/hand_open.png")

func _ready():
	# Set the default arrow cursor globally
	# The Vector2(0,0) is the "hotspot" (the click point of the image)
	Input.set_custom_mouse_cursor(default_cursor, Input.CURSOR_ARROW, Vector2(0, 0))
	
	# You can also set custom images for other system states
	Input.set_custom_mouse_cursor(interactive_cursor, Input.CURSOR_POINTING_HAND, Vector2(10, 0))

func set_cursor_busy():
	# Useful for loading states
	var busy_image = load("res://assets/kenney_cursor-pack/PNG/Outline/Default/busy_hourglass_outline.png")
	Input.set_custom_mouse_cursor(busy_image, Input.CURSOR_ARROW)

func reset_cursor():
	Input.set_custom_mouse_cursor(default_cursor)
