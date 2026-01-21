extends CanvasLayer

@onready var rect: ColorRect = $ColorRect
var target_path: String = ""
var fade_duration: float = 0.5
var other_func: Callable

var loading_tips: Array[String] = [
	"Press the 'Chat' key to talk with other players and coordinate your journey.",
	"Quick Command: Press the 'Command' key to open the chat with a '/' already typed for you.",
	"Stuck in a ditch? Type '/respawn' in the chat to return to the nearest spawn point.",
	"Host Tip: Keep the RV moving by using commands like '/refuel', '/reoil', and '/repair'.",
	"Host Tip: Is the battery running low? Use '/recharge' to top up the RV's power.",
	"Host Tip: Use '/sethour' followed by a number (0-23) to change the time of day instantly.",
	"Host Tip: You can toggle the weather by typing '/snow on' or '/snow off' in the console.",
	"Host Tip: Need an item in a pinch? Use '/spawn' followed by the item name (like 'gas_carton' or 'whiskey').",
	"Host Tip: Not feeling the current vibe? Skip the music track by typing '/advancetrack'.",
	"Items spawned via the '/spawn' command will appear wherever your crosshair is pointing.",
	"Host Tip: You can instantly change the world by typing '/changemap' followed by the map name.",
	"If things get floaty, the host can use '/gravity off' and '/gravity on' to reset physics.",
	"The top-left display shows your current FPS and the in-game world time.",
	"Host Tip: Use the '/save' command frequently to ensure the RV's progress is backed up."
]

func _ready():
	pass

func change_scene(path: String, given_other_func: Callable, duration: float = 0.5):
	target_path = path
	fade_duration = duration
	other_func = given_other_func
	
	$ColorRect/Label.text = loading_tips.pick_random()
	
	# Block input so user can't click during fade
	rect.mouse_filter = Control.MOUSE_FILTER_STOP
	
	# Start the chain
	var tween = create_tween()
	
	# Step A: Fade to black
	tween.tween_property(rect, "modulate:a", 1.0, fade_duration)
	
	# Step B: When Step A finishes, call the scene swap function
	tween.tween_callback(_perform_switch)
	
	# extra pause to see the menu screen
	tween.tween_property(rect, "modulate:a", 1.0, fade_duration)
	
	# Step C: Fade back to transparent
	tween.tween_property(rect, "modulate:a", 0.0, fade_duration)
	
	# Step D: Unlock input
	tween.tween_callback(func(): rect.mouse_filter = Control.MOUSE_FILTER_IGNORE)

func _perform_switch():
	if target_path != "":
		other_func.call()
		get_tree().change_scene_to_file(target_path)
