extends Node2D

# Reference the CanvasLayer child
@onready var menu_layer: CanvasLayer = $CanvasLayer 

# Get bus index by name (e.g., "SFX", "Music")
@onready var sfx_bus_index = AudioServer.get_bus_index("Sounds")
@onready var music_bus_index = AudioServer.get_bus_index("Music")
@onready var master_bus_index = AudioServer.get_bus_index("Master")

func _ready():
	# Hide the menu on start
	menu_layer.hide()

func _unhandled_input(event):
	if event.is_action_pressed("ui_cancel"):
		toggle_menu()
		
func toggle_menu():
	# play the toggle sound
	$AudioStreamPlayer2D.play()
	
	# Toggle visibility of the CanvasLayer
	menu_layer.visible = !menu_layer.visible


# works for both server and clients
func close_session():
	
	var callback = func():
		# 1. Check if a peer actually exists to avoid errors
		if multiplayer.multiplayer_peer:
			# .close() works for both Server and Client.
			# If Server: Disconnects all clients and shuts down.
			# If Client: Disconnects from the server.
			multiplayer.multiplayer_peer.close()
			
			# 2. Reset the multiplayer_peer to null to clean up the API state
			multiplayer.multiplayer_peer = null
	
	# 3. Return to the Main Menu scene
	#get_tree().change_scene_to_file("res://scenes/main.tscn")
	SceneTransition.change_scene("res://scenes/main.tscn", callback)
	
func _on_exit_menu_button_pressed() -> void:
	close_session()
	menu_layer.visible = false

func _on_exit_desktop_button_pressed() -> void:
	close_session()
	menu_layer.visible = false
	get_tree().quit()


func _on_music_slider_value_changed(value: float) -> void:
	# Convert to decibels (dB) for audio-friendly changes
	var db_value = linear_to_db(value)
	AudioServer.set_bus_volume_db(music_bus_index, db_value)


func _on_sound_slider_value_changed(value: float) -> void:
	# Convert to decibels (dB) for audio-friendly changes
	var db_value = linear_to_db(value)
	AudioServer.set_bus_volume_db(sfx_bus_index, db_value)
	

func _on_master_slider_value_changed(value: float) -> void:
	# Convert to decibels (dB) for audio-friendly changes
	var db_value = linear_to_db(value)
	AudioServer.set_bus_volume_db(master_bus_index, db_value)

func _on_fullscreen_check_box_toggled(toggled_on: bool) -> void:
	get_window().mode = Window.MODE_FULLSCREEN if toggled_on else Window.MODE_WINDOWED
