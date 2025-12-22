extends Node3D

@export var player_scene: PackedScene = preload("res://scenes/player.tscn")

func _ready():
	# Only the server manages spawning
	if not multiplayer.is_server():
		return

	multiplayer.peer_connected.connect(add_player)
	multiplayer.peer_disconnected.connect(remove_player)

	# Add the server's player
	add_player(1)

	# Add any players who joined while we were loading
	for id in multiplayer.get_peers():
		add_player(id)
		
func _process(_delta: float) -> void:
	# Get the FPS from the Engine singleton
	var fps = Engine.get_frames_per_second()
	
	# Update the label text
	# "FPS: %d" rounds the number to an integer
	$CanvasLayer/HBoxContainer/FPS.text = "FPS: %d" % fps
	
	# Optional: Change color based on performance
	if fps < 30:
		$CanvasLayer/HBoxContainer/FPS.add_theme_color_override("font_color", Color.RED)
	elif fps < 55:
		$CanvasLayer/HBoxContainer/FPS.add_theme_color_override("font_color", Color.YELLOW)
	else:
		$CanvasLayer/HBoxContainer/FPS.add_theme_color_override("font_color", Color.GREEN)

func add_player(id: int):
	var player = player_scene.instantiate()
	#spawn spot
	player.position = Vector3(9.39, 3.841, -2.935)
	player.name = str(id) # Name must be the peer ID
	$entities.add_child(player) # Add to a "Players" Node2D

func remove_player(id: int):
	var player = $entities.get_node_or_null(str(id))
	if player:
		player.queue_free()
