extends MultiplayerSpawner

@export var network_player: PackedScene

func _ready() -> void:
	# 1. Register the custom spawn function
	self.spawn_function = _custom_spawn_logic
	
	if is_multiplayer_authority():
		multiplayer.peer_connected.connect(add_new_player)
		multiplayer.peer_disconnected.connect(despawn_player)
		
		# Small delay or call_deferred is sometimes safer for the host player 
		# to ensure the network peer is fully initialized
		add_new_player.call_deferred(1)

func add_new_player(id: int) -> void:
	# Pass a dictionary of setup data
	var setup_data = {
		"id": id, 
		"skin": GameManager.selected_skin
	}
	# Calling spawn() triggers _custom_spawn_logic on ALL peers
	spawn(setup_data)

func _custom_spawn_logic(data: Variant) -> Node:
	var player = network_player.instantiate()
	
	# Set the name first so get_node(str(id)) works later
	player.name = str(data.id)
	
	# Apply visuals
	if player.has_method("set_skin_color"):
		player.set_skin_color(data.skin)
	
	var label = player.get_node_or_null("Label3D")
	if label:
		label.text = "Player " + str(data.id)
		
	return player

func despawn_player(id: int):
	# Use get_node(spawn_path) to find the container where players live
	var container = get_node(spawn_path)
	var player = container.get_node_or_null(str(id))
	if player:
		player.queue_free()
