@tool
extends EditorScript

# Set this to the folder containing your materials
const TARGET_DIR = "res://assets/snow_town/mats/" 

func _run():
	var dir = DirAccess.open(TARGET_DIR)
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if file_name.ends_with(".tres") or file_name.ends_with(".material"):
				var mat = load(TARGET_DIR + file_name)
				if mat is BaseMaterial3D:
					# 0 is Per-Pixel, 1 is Per-Vertex, 2 is Unshaded
					mat.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
					ResourceSaver.save(mat)
					print("Fixed shading for: ", file_name)
			file_name = dir.get_next()
	print("Batch Update Complete.")
