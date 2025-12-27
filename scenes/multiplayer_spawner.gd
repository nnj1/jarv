extends MultiplayerSpawner

@export var network_player: PackedScene

func _ready() -> void:
	self.spawn_function = _custom_spawn_logic
	
	if is_multiplayer_authority():
		# The server listens for people leaving to clean up
		multiplayer.peer_disconnected.connect(despawn_player)
		
		# Host spawns themselves immediately
		# Using a small timer or call_deferred to ensure the scene is ready
		_request_spawn_to_server.call_deferred(GameManager.selected_skin)
	else:
		# CLIENTS listen for the "connected_to_server" signal
		multiplayer.connected_to_server.connect(_on_connected_to_server)

# This only runs on the Client the moment they successfully handshake with the server
func _on_connected_to_server() -> void:
	_request_spawn_to_server.rpc_id(1, GameManager.selected_skin)

# The Server receives this and does the spawning
@rpc("any_peer", "call_local", "reliable")
func _request_spawn_to_server(skin_choice: Variant) -> void:
	if not is_multiplayer_authority():
		return
	
	var sender_id = multiplayer.get_remote_sender_id()
	if sender_id == 0: sender_id = 1 # Handle local host
	
	# Prevent double spawning if the signal fires twice
	if get_node(spawn_path).has_node(str(sender_id)):
		return
		
	var setup_data = {
		"id": sender_id, 
		"skin": skin_choice
	}
	
	spawn(setup_data)

func _custom_spawn_logic(data: Variant) -> Node:
	if network_player == null:
		push_error("Network Player PackedScene is not assigned!")
		return null
		
	var player = network_player.instantiate()
	player.name = str(data.id)
	player.set_multiplayer_authority(data.id)
	
	if player.has_method("set_skin_color"):
		player.set_skin_color(data.skin)
	
	var label = player.get_node_or_null("Label3D")
	if label:
		label.text = "Player " + str(data.id)
		
	return player

func despawn_player(id: int):
	var container = get_node(spawn_path)
	var player = container.get_node_or_null(str(id))
	if player:
		player.queue_free()
