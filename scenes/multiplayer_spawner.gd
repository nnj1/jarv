extends MultiplayerSpawner

@export var network_player: PackedScene

func _ready() -> void:
	
	# set up signals when other players connect and disconnect
	multiplayer.peer_connected.connect(spawn_player.bind(GameManager.selected_skin))
	multiplayer.peer_disconnected.connect(despawn_player)
	
	# spawn the first player (aka the server)
	spawn_player(1, GameManager.selected_skin)

func spawn_player(id: int, skin_color: Color) -> void:
	if not multiplayer.is_server(): return
	
	var player: Node = network_player.instantiate()
	player.name = str(id)
	
	# set up the player's skin
	player.set_skin_color(skin_color)
	
	get_node(spawn_path).call_deferred("add_child", player)
	print('Spawned ' + str(player.name))
	
func despawn_player(_player_node):
	print('Despawned ' + str(_player_node))
