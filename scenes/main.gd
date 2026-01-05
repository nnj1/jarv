extends Node

@export var default_names = [
  "SnowyBooty",
  "FrostyCheeks",
  "IcyBooty",
  "ChillyCheeks",
  "PowderBooty",
  "BlizzardCheeks",
  "ArcticBooty",
  "GlacierCheeks",
  "WinterBooty",
  "SlushyCheeks",
  "FlurryBooty",
  "FrozenCheeks",
  "BootyBlizzard",
  "CheeksOfIce",
  "TundraBooty",
  "SubZeroCheeks",
  "BootyAvalanche",
  "RosyCheeksWinter",
  "DriftBooty",
  "AlpineCheeks",
  "SleetBooty",
  "ShiverCheeks",
  "HailStoneBooty",
  "FrostbiteCheeks",
  "EvergreenBooty",
  "AmitArctic",
  "ReddyFrost",
  "Amit_On_Ice",
  "ReddyToSki",
  "AmitAvalanche",
  "ReddyForSnow",
  "SummitAmit",
  "Reddy_SubZero",
  "AmitAlps",
  "ReddyGlacier",
  "AmitBlizzard",
  "ReddyWinter",
  "AmitTheIceKing",
  "ReddyChill",
  "AmitSnowfall",
  "ReddyFreeze",
  "AmitColdSnap",
  "ReddyTundra",
  "AmitWhiteout",
  "ReddyIcicle",
  "AmitBooty",
  "ReddyCheeks",
  "AmitFrostyBooty",
  "ReddyIceCheeks",
  "Amit_Booty_Blizzard",
  "Reddy_Snowy_Cheeks",
  "AmitPowderCheeks",
  "ReddyArcticBooty",
  "AmitTheCheekySnowman",
  "ReddyBootyDrift"
]

@export var listen_port: int = 8910
@onready var item_list = $"CanvasLayer/VBoxContainer/TabContainer/Server Browser"

var listener := PacketPeerUDP.new()
var known_servers := {} # { "IP": {"name": String, "players": int, "port": int, "last_seen": float} }

func _ready() -> void:
	
	# load map options
	var map_files = GlobalVars.dir_contents('res://scenes/maps/')
	var map_scenes = map_files.filter(func(file): return file.get_extension() == "tscn")
	for map_scene in map_scenes:
		$"CanvasLayer/VBoxContainer/TabContainer/Create Server/HBoxContainer/OptionButton2".add_item(map_scene)
	GameManager.starting_map_string = map_scenes[0].get_basename()
	
	$CanvasLayer/VBoxContainer/TabContainer.current_tab = 0
	
	# Bind the UDP listener
	var err = listener.bind(listen_port)
	if err != OK:
		print("UDP Listener: Port busy (likely another debug instance).")
	
	# Connect the item list signal
	item_list.item_selected.connect(_on_item_activated)
	
	# preset default username
	$CanvasLayer/VBoxContainer/HBoxContainer2/TextEdit.text = default_names.pick_random()
	GameManager.selected_username = $CanvasLayer/VBoxContainer/HBoxContainer2/TextEdit.text
	
	# preset default skin color
	set_random_color($CanvasLayer/VBoxContainer/HBoxContainer2/ColorPickerButton)
	GameManager.selected_skin = $CanvasLayer/VBoxContainer/HBoxContainer2/ColorPickerButton.color
	
var retry_timer := 0.0

func _process(delta: float) -> void:
	# only activate create server if create server tab is open
	if $CanvasLayer/VBoxContainer/TabContainer.current_tab == 0:
		$CanvasLayer/VBoxContainer/HBoxContainer2/Button.disabled = false
	else:
		$CanvasLayer/VBoxContainer/HBoxContainer2/Button.disabled = true
	# only activate join server if server browser tab is open
	if $CanvasLayer/VBoxContainer/TabContainer.current_tab == 1:
		$CanvasLayer/VBoxContainer/HBoxContainer2/Button2.disabled = false
	else:
		$CanvasLayer/VBoxContainer/HBoxContainer2/Button2.disabled = true	
	# 1. If not bound, try to grab the port once every second
	if not listener.is_bound():
		retry_timer += delta
		if retry_timer >= 1.0:
			retry_timer = 0.0
			var err = listener.bind(listen_port)
			if err == OK:
				print("Successfully grabbed the port! Now listening...")
		return # Exit early: if we aren't bound, there's no data to read

	# 2. Listen for new pings (only runs if bound)
	while listener.get_available_packet_count() > 0:
		var server_ip = listener.get_packet_ip()
		var bytes = listener.get_packet()
		
		# Safer parsing: parse_string can return null if the packet is malformed
		var data = JSON.parse_string(bytes.get_string_from_utf8())
		
		if data is Dictionary:
			data["last_seen"] = Time.get_unix_time_from_system()
			known_servers[server_ip] = data
			_refresh_ui()
	
func _on_host_pressed():
	# 1. Stop listening so another debug window can take the port	
	stop_listening()
	
	GameManager.start_server(int($CanvasLayer/VBoxContainer/HBoxContainer/TextEdit2.text))
	#TODO: Get the scene transition to work without destroying multiplayer connectivity
	#SceneTransition.change_scene('res://scenes/game.tscn')
	get_tree().change_scene_to_file('res://scenes/game.tscn')

func _on_join_pressed():
	GameManager.start_client($CanvasLayer/VBoxContainer/HBoxContainer/TextEdit.text)
	#SceneTransition.change_scene('res://scenes/game.tscn')
	get_tree().change_scene_to_file('res://scenes/game.tscn')

func _on_color_picker_button_color_changed(color: Color) -> void:
	GameManager.selected_skin = color

func _on_text_edit_text_changed(new_text:String) -> void:
	GameManager.selected_username = new_text

## Takes any ColorPicker or ColorPickerButton and assigns a random vibrant color
func set_random_color(picker_node: Control) -> void :
	if picker_node.has_method("set_pick_color") or "color" in picker_node:
		# Using HSV for a "cleaner" default color look
		var random_hue: float = randf()
		var saturation: float = 0.8
		var value: float = 0.9
		
		var new_color = Color.from_hsv(random_hue, saturation, value)
		picker_node.color = new_color
	else:
		push_error("The node passed to set_random_color does not have a color property.")

func _refresh_ui():
	item_list.clear()
	var now = Time.get_unix_time_from_system()
	
	# We use a loop to filter out old servers and rebuild the list
	for ip in known_servers.keys():
		var server = known_servers[ip]
		
		# Remove if not seen in 3 seconds
		if now - server["last_seen"] > 3.0:
			known_servers.erase(ip)
			continue
		
		# Create the text for the list item
		var display_text = "%s | %s Players | IP: %s" % [server.name, server.players, ip]
		
		# Add to the ItemList
		var index = item_list.add_item(display_text)
		
		# Store the IP and Port as "metadata" so we can retrieve it when clicked
		item_list.set_item_metadata(index, {"ip": ip, "port": server.port})

func _on_item_activated(index: int):
	# This triggers when you double-click or press enter on an item
	var meta = item_list.get_item_metadata(index)
	print("Populating fields with: ", meta.ip, " on port: ", meta.port)
	# NetworkManager.join_game(meta.ip, meta.port)
	# populate the fields
	$CanvasLayer/VBoxContainer/HBoxContainer/TextEdit.text = str(meta.ip)
	$CanvasLayer/VBoxContainer/HBoxContainer/TextEdit2.text = str(int(meta.port))

func stop_listening():
	if listener.is_bound():
		listener.close()
		print("UDP Listener closed. Port 8910 is now free.")


func _on_button_pressed() -> void:
	$"CanvasLayer/VBoxContainer/TabContainer/Create Server/FileDialog".visible = true



func _on_line_edit_text_changed(new_text: String) -> void:
	GameManager.new_game_name = new_text

func _on_check_button_toggled(toggled_on: bool) -> void:
	GameManager.friendly_fire = toggled_on

func _on_check_button_2_toggled(toggled_on: bool) -> void:
	GameManager.auto_save = toggled_on 
	
func _on_option_button_item_selected(index: int) -> void:
	GameManager.max_players = index

func _on_option_button_2_item_selected(index: int) -> void:
	GameManager.starting_map_string = $"CanvasLayer/VBoxContainer/TabContainer/Create Server/HBoxContainer/OptionButton2".get_item_text(index).get_basename()

func _on_file_dialog_file_selected(path: String) -> void:
	$'CanvasLayer/VBoxContainer/TabContainer/Create Server/HBoxContainer2/LineEdit'.text = path
