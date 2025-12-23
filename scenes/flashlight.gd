extends SpotLight3D

@export var follow_speed: float = 10.0
@export var toggle_sound: AudioStreamPlayer3D

func _ready():
	# Start with the light off
	visible = false

func _input(event):
	# Use "F" key to toggle
	if event.is_action_pressed("flashlight_toggle") or Input.is_key_pressed(KEY_F):
		visible = !visible
		if toggle_sound:
			toggle_sound.play()

func _process(delta):
	# SMOOTHING: This makes the light lag slightly behind the camera movement
	# This creates a much more immersive "handheld" feel.
	var target_rotation = get_parent().global_transform.basis.get_euler()
	global_rotation.x = lerp_angle(global_rotation.x, target_rotation.x, delta * follow_speed)
	global_rotation.y = lerp_angle(global_rotation.y, target_rotation.y, delta * follow_speed)
