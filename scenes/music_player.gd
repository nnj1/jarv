extends AudioStreamPlayer

var music_folder = "res://assets/music/"
var playlist = []
var current_track_index = 0

func _ready():
	load_music_from_folder()
	play_current_track()
	
	# Connect the finished signal to automatically play the next song
	finished.connect(_on_finished)

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
