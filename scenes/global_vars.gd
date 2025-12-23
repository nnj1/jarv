extends Node

# Load your spritesheet
@onready var spritesheet = preload('res://assets/kenney_crosshairPack/Tilesheet/crosshairs_tilesheet_white.png')

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
func dir_contents(path):
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
