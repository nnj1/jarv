extends AudioStreamPlayer

# --- Configuration ---
@export var music_folder: String = "res://assets/music/"
@export var menu_music_path: String = "res://assets/music/Menu_Theme.mp3"

var playlist: Array[String] = []

# --- SFX Assets ---
var hover_sfx = preload("res://assets/UI Soundpack/UI Soundpack/MP3/Modern3.mp3")
var click_sfx = preload("res://assets/UI Soundpack/UI Soundpack/MP3/Modern4.mp3")
var sfx_player: AudioStreamPlayer

func _ready():
	load_music_from_folder()
	
	# 1. Setup SFX Player (Local only)
	sfx_player = AudioStreamPlayer.new()
	add_child(sfx_player)
	sfx_player.bus = "Sounds"
	
	# 2. Initialize UI Audio Connections
	setup_controls(get_tree().root)
	get_tree().node_added.connect(_on_node_added)
	
	# 3. Connect signals
	finished.connect(_on_finished)
	
	# 4. Multiplayer Signals
	multiplayer.server_disconnected.connect(_on_disconnected)
	multiplayer.connection_failed.connect(_on_disconnected)
	
	# 5. Start Menu Music immediately
	play_menu_music()

func load_music_from_folder():
	var dir = DirAccess.open(music_folder)
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if !dir.current_is_dir() and (file_name.ends_with(".mp3") or file_name.ends_with(".ogg")):
				playlist.append(music_folder + file_name)
			file_name = dir.get_next()
	else:
		print("Warning: Music folder not found at ", music_folder)

func play_menu_music():
	if FileAccess.file_exists(menu_music_path):
		var stream_res = load(menu_music_path)
		if self.stream != stream_res:
			self.stream = stream_res
			self.play()
	elif playlist.size() > 0:
		play_track_locally(playlist.pick_random())

func play_track_locally(path: String):
	self.stream = load(path)
	self.play()

# --- Multiplayer Lifecycle ---

# IMPORTANT: Call this from your Host button logic
func start_multiplayer_session():
	if not multiplayer.is_server(): return
	
	# Server connects to the peer signal to catch late joiners
	if not multiplayer.peer_connected.is_connected(_on_player_connected):
		multiplayer.peer_connected.connect(_on_player_connected)
	
	# Host switches from Menu Music to first Playlist track for everyone
	if playlist.size() > 0:
		sync_track_to_all.rpc(playlist[0], 0.0)

func _on_player_connected(id: int):
	# Server tells the specific new player what is currently playing
	if multiplayer.is_server() and self.stream != null:
		sync_track_to_all.rpc_id(id, self.stream.resource_path, get_playback_position())

func _on_disconnected():
	# If we leave a server, revert to menu music
	play_menu_music()

# --- Synchronization RPC ---

@rpc("authority", "call_local", "reliable")
func sync_track_to_all(track_path: String, timestamp: float):
	if not FileAccess.file_exists(track_path):
		print("Error: Missing music file: ", track_path)
		return

	var new_stream = load(track_path)
	
	# Change track if it's different from current
	if self.stream == null or self.stream.resource_path != track_path:
		self.stream = new_stream
		self.play()
	
	# Late joiner sync: Only seek if the difference is more than 0.5s
	if abs(get_playback_position() - timestamp) > 0.5:
		seek(timestamp)

func _on_finished():
	# If we are just in the menu (disconnected), loop menu music
	if not multiplayer.has_multiplayer_peer() or multiplayer.multiplayer_peer.get_connection_status() == MultiplayerPeer.CONNECTION_DISCONNECTED:
		play_menu_music()
		return

	# If in multiplayer, only the server decides what plays next
	if multiplayer.is_server():
		var current_path = self.stream.resource_path if self.stream else ""
		var current_idx = playlist.find(current_path)
		var next_idx = (current_idx + 1) % playlist.size() if current_idx != -1 else 0
		sync_track_to_all.rpc(playlist[next_idx], 0.0)

# --- Public Controls ---

func skip_track():
	if multiplayer.is_server():
		_on_finished()
	elif multiplayer.has_multiplayer_peer():
		# Clients ask server to skip
		request_skip.rpc_id(1)

@rpc("any_peer", "call_remote", "reliable")
func request_skip():
	if multiplayer.is_server():
		_on_finished()

# --- UI SFX Logic (Local) ---

func _on_node_added(node):
	if node is Button:
		_connect_signals(node)

func setup_controls(node):
	if node is Button:
		_connect_signals(node)
	for child in node.get_children():
		setup_controls(child)

func _connect_signals(node: Control):
	if not node.mouse_entered.is_connected(_play_hover):
		node.mouse_entered.connect(_play_hover)
	if not node.gui_input.is_connected(_on_gui_input):
		node.gui_input.connect(_on_gui_input)

func _play_hover():
	_play_sound(hover_sfx)

func _on_gui_input(event):
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			_play_sound(click_sfx)

func _play_sound(stream_to_play: AudioStream):
	if stream_to_play:
		sfx_player.stream = stream_to_play
		sfx_player.play()
