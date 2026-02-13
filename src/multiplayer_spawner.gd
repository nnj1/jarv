extends MultiplayerSpawner

@onready var main_game_node = get_tree().get_root().get_node('Node3D')

@export var network_player: PackedScene

func _ready() -> void:
	self.spawn_function = _custom_spawn_logic
	
	if is_multiplayer_authority():
		# The server listens for people leaving to clean up
		multiplayer.peer_disconnected.connect(despawn_player)
		
		# Host spawns themselves immediately
		# Using a small timer or call_deferred to ensure the scene is ready
		_request_spawn_to_server.call_deferred(GameManager.selected_skin, GameManager.selected_username)
	else:
		# CLIENTS listen for the "connected_to_server" signal
		multiplayer.connected_to_server.connect(_on_connected_to_server)
		# Clients connect to this to detect if the host closed the game
		multiplayer.server_disconnected.connect(_on_server_disconnected)

# This only runs on the Client the moment they successfully handshake with the server
func _on_connected_to_server() -> void:
	_request_spawn_to_server.rpc_id(1, GameManager.selected_skin, GameManager.selected_username)

# The Server receives this and does the spawning
@rpc("any_peer", "call_local", "reliable")
func _request_spawn_to_server(skin_choice: Variant, username: String = '') -> void:
	if not is_multiplayer_authority():
		return
	
	var sender_id = multiplayer.get_remote_sender_id()
	if sender_id == 0: sender_id = 1 # Handle local host
	if username == '': username = str(sender_id)
	# Prevent double spawning if the signal fires twice
	if get_node(spawn_path).has_node(str(sender_id)):
		return
		
	var setup_data = {
		"id": sender_id, 
		"skin": skin_choice,
		"username": username,
		# THS IS ANY ADDITIONAL STUFF YOU WANT TO SEND THE PLAYER WHEN THEY SPAWN
		# RV DATA WILL BE USEFUL FOR PLAYER TO DESERIALIZE THE RV
		"host_server_data": {
			'friendly_fire': GameManager.friendly_fire,
			'rv_data': GameManager.rv_data
		}
	}
	
	spawn(setup_data)

func _custom_spawn_logic(data: Variant) -> Node:
	if network_player == null:
		push_error("Network Player PackedScene is not assigned!")
		return null
		
	var player = network_player.instantiate()
	
	player.host_server_data = data.host_server_data
	player.name = str(data.id)
	player.username = str(data.username)
	player.set_multiplayer_authority(data.id)
	
	if player.has_method("set_skin_color"):
		player.set_skin_color(data.skin)
	
	var label = player.get_node_or_null("Label3D")
	if label:
		label.text = str(data.username)
		
	return player

func despawn_player(id: int):
	var container = get_node(spawn_path)
	var player = container.get_node_or_null(str(id))
	if player:
		player.queue_free()
		# TODO: leave a message
		main_game_node.rpc('send_chat', 'Disconnected from game.', str(id))

func _on_server_disconnected():
	# Clean up locally and send the client back to the menu
	multiplayer.multiplayer_peer = null
	get_tree().change_scene_to_file("res://scenes/main.tscn")
