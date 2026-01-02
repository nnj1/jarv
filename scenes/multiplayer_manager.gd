extends Node

var peer = ENetMultiplayerPeer
var ROLE = null

var connected_peer_ids = []
var local_player_character
var UniquePeerID : String
var selected_username:String = ''
var selected_skin = Color(1,0,0)

var game_name:String
var current_port:int

func start_server(PORT = 9999, given_game_name='generic game') -> void:
	self.ROLE = 'Server'
	peer = ENetMultiplayerPeer.new()
	peer.create_server(PORT)
	multiplayer.multiplayer_peer = peer
	current_port = PORT
	game_name = given_game_name
	
func start_client(ADDRESS = 'localhost', PORT = 9999):
	self.ROLE = 'Client'
	peer = ENetMultiplayerPeer.new()
	
	# TODO: get this working
	var error = peer.create_client(ADDRESS, PORT)
	if error != OK:
		# Handle immediate creation errors (e.g., ERR_ALREADY_IN_USE)
		print("Error setting up client peer: ", error)
		return false
	multiplayer.multiplayer_peer = peer
	
	return true
