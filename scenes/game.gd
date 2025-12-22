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
