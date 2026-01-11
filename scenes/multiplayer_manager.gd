extends Node

var peer = ENetMultiplayerPeer
var ROLE = null

var connected_peer_ids = []
var local_player_character
var UniquePeerID : String
var selected_username:String = ''
var selected_skin = Color(1,0,0)

# Variables that are important for the server. Only mess with these if the game instance is_server()
var game_name:String
var new_game_name:String # custom server name
var max_players:int = 0
var friendly_fire = true
var auto_save = false
var current_port:int
var starting_map_string:String
var path_for_save:String
var rv_data: Dictionary

func start_server(PORT = 9999, given_game_name=GameManager.selected_username + "'s Game") -> void:
	self.ROLE = 'Server'
	peer = ENetMultiplayerPeer.new()
	peer.create_server(PORT)
	multiplayer.multiplayer_peer = peer
	current_port = PORT
	if not new_game_name:
		game_name = given_game_name
	else:
		game_name = new_game_name
	# TODO: ensure RV save data is valid
	if path_for_save:
		rv_data = GlobalVars.load_json_file(path_for_save)
		#print(rv_data)
	else:
		# create new generic data for RV
		rv_data = {
			"metadata": {
				"name": "Generic RV Name",
				"stats": {
					"current_fuel": 100, "max_fuel": 100,
					"current_health": 100, "max_health": 100,
					"current_battery": 100, "max_battery": 100,
					"current_oil": 100, "max_oil": 100
				},
				"materials": {
					"rusty_scrap": 0,
					"wiring_components": 0,
					"refined_plates": 0,
					"processor_chips": 0,
					"chemical_sludge": 0
				},
				"tech_tree": {
					"patch_kit": {
						"name": "External Patch Kit",
						"description": "Allows hull repairs while the RV is in motion.",
						"unlocked": true,
						"requirements": { "rusty_scrap": 20, "wiring_components": 5 }
					},
					"solar_roof": {
						"name": "Solar Array",
						"description": "Slowly regenerates energy during daylight hours.",
						"unlocked": false,
						"requirements": { "wiring_components": 50, "processor_chips": 2 }
					},
					"oil_reclaimer": {
						"name": "Oil Reclaimer",
						"description": "Recycles engine exhaust to reduce oil consumption by 20%.",
						"unlocked": false,
						"requirements": { "rusty_scrap": 60, "chemical_sludge": 5 }
					},
					"thermal_insulation": {
						"name": "Thermal Insulation",
						"description": "Reduces energy drain from heaters during night-time travel.",
						"unlocked": false,
						"requirements": { "rusty_scrap": 40, "chemical_sludge": 8 }
					},
					"automated_siphon": {
						"name": "High-Flow Siphon",
						"description": "Increases speed of fuel extraction from abandoned vehicles.",
						"unlocked": false,
						"requirements": { "wiring_components": 15, "rusty_scrap": 30 }
					},
					"radar_array": {
						"name": "Scrap Radar",
						"description": "Highlights nearby scavenging nodes on the HUD.",
						"unlocked": false,
						"requirements": { "processor_chips": 3, "wiring_components": 40 }
					},
					"heavy_bullbar": {
						"name": "Reinforced Bullbar",
						"description": "Reduces damage taken when hitting obstacles or enemies.",
						"unlocked": false,
						"requirements": { "refined_plates": 10, "rusty_scrap": 80 }
					},
					"bio_converter": {
						"name": "Bio-Fuel Converter",
						"description": "Allows the engine to burn Chemical Sludge as emergency fuel.",
						"unlocked": false,
						"requirements": { "chemical_sludge": 20, "processor_chips": 1, "wiring_components": 25 }
					},
					"shield_generator": {
						"name": "Electro-Shield",
						"description": "Consumes energy to block the next 3 incoming attacks.",
						"unlocked": false,
						"requirements": { "processor_chips": 5, "refined_plates": 12, "wiring_components": 100 }
					}
				}
			},
			"grid_items": []
		}
	
	MusicPlayer.start_multiplayer_session()

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
