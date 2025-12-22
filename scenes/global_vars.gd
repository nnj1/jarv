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
