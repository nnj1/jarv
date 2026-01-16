extends CanvasLayer

var rect: ColorRect
var target_path: String = ""
var fade_duration: float = 0.5

func _ready():
	# 1. Setup the UI purely via code
	rect = ColorRect.new()
	add_child(rect)
	rect.color = Color.BLACK
	rect.modulate.a = 0.0
	rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE

func change_scene(path: String, duration: float = 1.0):
	target_path = path
	fade_duration = duration
	
	# Block input so user can't click during fade
	rect.mouse_filter = Control.MOUSE_FILTER_STOP
	
	# Start the chain
	var tween = create_tween()
	
	# Step A: Fade to black
	tween.tween_property(rect, "modulate:a", 1.0, fade_duration)
	
	# Step B: When Step A finishes, call the scene swap function
	tween.tween_callback(_perform_switch)
	
	# Step C: Fade back to transparent
	tween.tween_property(rect, "modulate:a", 0.0, fade_duration)
	
	# Step D: Unlock input
	tween.tween_callback(func(): rect.mouse_filter = Control.MOUSE_FILTER_IGNORE)

func _perform_switch():
	if target_path != "":
		get_tree().change_scene_to_file(target_path)
