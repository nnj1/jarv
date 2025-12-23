extends Node

var enet_peer = ENetMultiplayerPeer.new()

func host_game(PORT = 9999):
	enet_peer.create_server(PORT)
	multiplayer.multiplayer_peer = enet_peer
	# Change to the game scene immediately
	#get_tree().change_scene_to_file("res://scenes/game.tscn")
	SceneTransition.change_scene('res://scenes/game.tscn')

func join_game(address = "localhost", PORT = 9999):
	enet_peer.create_client(address, PORT)
	multiplayer.multiplayer_peer = enet_peer
	# The client waits for the server to load the scene (handled by Spawner)
	#get_tree().change_scene_to_file("res://scenes/game.tscn")
	SceneTransition.change_scene('res://scenes/game.tscn')

@rpc("any_peer", "call_local", "reliable")
func load_game_rpc():
	get_tree().change_scene_to_file("res://scenes/game.tscn")

# In host_game(), instead of changing scene directly, call:
# load_game_rpc.rpc()
