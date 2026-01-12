extends Node

# Load your spritesheet
@onready var spritesheet = preload('res://assets/kenney_crosshairPack/Tilesheet/crosshairs_tilesheet_white.png')
@onready var idle_sound_streams = []

func _ready() -> void:
	var grunt_sound_path = 'res://assets/Lickspittle/Grunting/'
	for filename in dir_contents(grunt_sound_path):
		idle_sound_streams.append(load(grunt_sound_path + filename))

func get_cursor_texture(frame_index: int, columns: int, rows: int, spacing: int = 5) -> ImageTexture:
	var sheet_image: Image = spritesheet.get_image()
	
	# 1. Calculate the width/height of a single frame
	# Total Width = (columns * frame_w) + ((columns - 1) * spacing)
	# Solving for frame_w:
	@warning_ignore("integer_division")
	var frame_w = (sheet_image.get_width() - (spacing * (columns - 1))) / columns
	@warning_ignore("integer_division")
	var frame_h = (sheet_image.get_height() - (spacing * (rows - 1))) / rows
	
	# 2. Calculate the top-left corner of the desired frame
	var column = frame_index % columns
	@warning_ignore("integer_division")
	var row = frame_index / columns
	
	var x = column * (frame_w + spacing)
	var y = row * (frame_h + spacing)
	
	# 3. Extract the region
	# We use Rect2i (integer rect) for pixel-perfect cropping
	var region = Rect2i(int(x), int(y), int(frame_w), int(frame_h))
	var frame_image: Image = sheet_image.get_region(region)
	
	# 4. Return as a texture for your Sprite2D/TextureRect
	return ImageTexture.create_from_image(frame_image)

# useful function for searching through a list of json documents 
# and retrieving the value for a key for a document that has a certain id
func searchDocsInList(list, uniquekey: String, uniqueid: String, key: String):
	for doc in list:
		if doc[uniquekey] == uniqueid:
			if key in doc.keys():
				return doc[key]
			else:
				return null
	return null

# useful function for searching through a list of json documents
# and retrieving doc where there is a certain value for a certain key
func returnDocInList(list, uniquekey, uniqueid):
	for doc in list:
		if doc[uniquekey] == uniqueid:
			return doc
	return null
	
# useful function for making an array unique
func array_unique(array: Array) -> Array:
	var unique: Array = []
	for item in array:
		if not unique.has(item):
			unique.append(item)
	return unique

#useful function for picking a random value from a list
func choose_random_from_list(rand_list):
	return rand_list[randi() % rand_list.size()]

#useful function for returning a list of files in a directory
func dir_contents_old(path):
	var files = []
	var dir = DirAccess.open(path)
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if dir.current_is_dir():
				#print("Found directory: " + file_name)
				pass
			else:
				if file_name.find('.import') == -1:
					#print("Found file: " + file_name)
					files.append(file_name)
			file_name = dir.get_next()
	else:
		#print("An error occurred when trying to access the path.")
		pass
	return files
	
func dir_contents(path: String) -> Array:
	var filenames = []
	var dir = DirAccess.open(path)
	
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		
		while file_name != "":
			if !dir.current_is_dir():
				# 1. Clean the path to handle exported naming conventions
				var full_path = path.path_join(file_name)
				var clean_path = full_path.replace(".remap", "").replace(".import", "")
				
				# 2. Check if Godot recognizes it as a resource
				if ResourceLoader.exists(clean_path):
					# 3. Extract just the name (e.g., "level1.tscn")
					var just_the_file = clean_path.get_file()
					
					if !filenames.has(just_the_file):
						filenames.append(just_the_file)
			
			file_name = dir.get_next()
		dir.list_dir_end()
	else:
		printerr("Error: Could not open path: ", path)
	
	return filenames

func load_json_file(file_path: String):
	# 1. Check if the file exists
	if not FileAccess.file_exists(file_path):
		print("File does not exist at path: ", file_path)
		return null
		
	# 2. Open the file for reading
	var file = FileAccess.open(file_path, FileAccess.READ)
	if file == null:
		print("Error opening file: ", FileAccess.get_open_error())
		return null
		
	# 3. Read the content as text
	var content = file.get_as_text()
	file.close()
	
	# 4. Parse the string into a Godot-readable format
	var json_data = JSON.parse_string(content)
	
	if json_data == null:
		print("Failed to parse JSON string.")
		return null
		
	return json_data
