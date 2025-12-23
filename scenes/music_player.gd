extends AudioStreamPlayer

var music_folder = "res://assets/music/"
var playlist = []
var current_track_index = 0

# Load your sounds here
var hover_sfx = preload("res://assets/UI Soundpack/UI Soundpack/MP3/Modern3.mp3")
var click_sfx = preload("res://assets/UI Soundpack/UI Soundpack/MP3/Modern4.mp3")

var sfx_player: AudioStreamPlayer

func _ready():
	load_music_from_folder()
	play_current_track()
	
	# Connect the finished signal to automatically play the next song
	finished.connect(_on_finished)
	
	# Setup a single audio player to reuse for sound effects
	sfx_player = AudioStreamPlayer.new()
	add_child(sfx_player)
	sfx_player.bus = "Sounds" # Optional: Route to an SFX audio bus
	
	# Connect to existing and future nodes
	setup_controls(get_tree().root)
	get_tree().node_added.connect(_on_node_added)

func load_music_from_folder():
	var dir = DirAccess.open(music_folder)
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			# Only load supported audio files
			if !dir.current_is_dir() and (file_name.ends_with(".mp3") or file_name.ends_with(".ogg")):
				playlist.append(music_folder + file_name)
			file_name = dir.get_next()
	else:
		print("An error occurred when trying to access the path.")

func play_current_track():
	if playlist.size() > 0:
		var track_path = playlist[current_track_index]
		@warning_ignore("shadowed_variable_base_class")
		var stream = load(track_path)
		self.stream = stream
		self.play()
		print("Playing: ", track_path)

func _on_finished():
	# Increment index and loop back to 0 if at the end
	current_track_index = (current_track_index + 1) % playlist.size()
	play_current_track()

# Optional: Functions to control music from other scenes
func skip_track():
	_on_finished()

func previous_track():
	current_track_index = (current_track_index - 1 + playlist.size()) % playlist.size()
	play_current_track()

func _on_node_added(node):
	if node is Button:
		_connect_signals(node)

func setup_controls(node):
	if node is Button:
		_connect_signals(node)
	for child in node.get_children():
		setup_controls(child)

func _connect_signals(node: Control):
	# We use CONNECT_DEFERRED to ensure we don't interfere with the tree setup
	if not node.mouse_entered.is_connected(_play_hover):
		node.mouse_entered.connect(_play_hover)
	if not node.gui_input.is_connected(_on_gui_input):
		node.gui_input.connect(_on_gui_input)

# --- Sound Logic ---
func _play_hover():
	_play_sound(hover_sfx)

func _on_gui_input(event):
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			_play_sound(click_sfx)

@warning_ignore("shadowed_variable_base_class")
func _play_sound(stream: AudioStream):
	if stream:
		sfx_player.stream = stream
		sfx_player.play()
