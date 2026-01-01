extends Node3D

@onready var main_game_node = get_tree().get_root().get_node('Node3D')

@export_group("Terrain Settings")
@export var chunk_size: int = 32
@export var chunk_radius: int = 4
@export var height_scale: float = 15.0

@export_group("Scattering Folders")
# Points to folders containing your .blend or .tscn files
@export_dir var tree_folder: String = "res://assets/psx_nature/bushes/"
@export_dir var bush_folder: String = "res://assets/psx_nature/trees/"
@export var scatter_density: float = 0.2

@export_group("Noise Configuration")
@export var terrain_noise: FastNoiseLite = FastNoiseLite.new()
@export var density_noise: FastNoiseLite = FastNoiseLite.new()

var chunks = {} # {Vector2i: MeshInstance3D}
var tree_scenes: Array[PackedScene] = []
var bush_scenes: Array[PackedScene] = []
var terrain_material: ShaderMaterial
var player: Node3D

func _ready():
	player = main_game_node.get_node('entities/1')
	
	# Setup Noise
	terrain_noise.seed = randi()
	terrain_noise.frequency = 0.015
	terrain_noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	
	density_noise.seed = randi() + 1
	density_noise.frequency = 0.05
	
	setup_shader_material()
	
	# Load .blend or .tscn files as PackedScenes
	tree_scenes = load_scenes_from_dir(tree_folder)
	bush_scenes = load_scenes_from_dir(bush_folder)

func load_scenes_from_dir(path: String) -> Array[PackedScene]:
	var arr: Array[PackedScene] = []
	var dir = DirAccess.open(path)
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			# Godot treats .blend as a scene upon import
			if not dir.current_is_dir() and (file_name.ends_with(".blend") or file_name.ends_with(".tscn") or file_name.ends_with(".scn")):
				var scene = load(path + "/" + file_name)
				if scene is PackedScene:
					arr.append(scene)
			file_name = dir.get_next()
	return arr

func setup_shader_material():
	var shader = Shader.new()
	shader.code = """
	shader_type spatial;
	varying float world_height;
	void vertex() { world_height = (MODEL_MATRIX * vec4(VERTEX, 1.0)).y; }
	void fragment() {
		vec3 sand = vec3(0.76, 0.70, 0.50);
		vec3 grass = vec3(0.22, 0.38, 0.15);
		vec3 rock = vec3(0.35, 0.32, 0.28);
		float h = world_height;
		vec3 col = mix(sand, grass, smoothstep(1.0, 3.5, h));
		col = mix(col, rock, smoothstep(8.0, 12.0, h));
		ALBEDO = col;
		ROUGHNESS = 0.8;
	}
	"""
	terrain_material = ShaderMaterial.new()
	terrain_material.shader = shader

func _process(_delta):
	if player:
		update_chunks()

func update_chunks():
	var p_pos = player.global_position
	var p_x = int(floor(p_pos.x / chunk_size))
	var p_z = int(floor(p_pos.z / chunk_size))
	var current_coord = Vector2i(p_x, p_z)
	
	for x in range(p_x - chunk_radius, p_x + chunk_radius):
		for z in range(p_z - chunk_radius, p_z + chunk_radius):
			var coord = Vector2i(x, z)
			if not chunks.has(coord):
				chunks[coord] = null 
				WorkerThreadPool.add_task(create_chunk_data.bind(coord))
	
	var to_remove = []
	for coord in chunks:
		if coord.distance_to(current_coord) > chunk_radius + 1:
			to_remove.append(coord)
	for coord in to_remove:
		if chunks[coord]: chunks[coord].queue_free()
		chunks.erase(coord)

# --- BACKGROUND THREAD ---
func create_chunk_data(coord: Vector2i):
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	
	var x_off = coord.x * chunk_size
	var z_off = coord.y * chunk_size

	# Terrain Generation with Smoothing Padding
	for z in range(-1, chunk_size + 2):
		for x in range(-1, chunk_size + 2):
			var y = terrain_noise.get_noise_2d(x_off + x, z_off + z) * height_scale
			st.set_uv(Vector2(float(x)/chunk_size, float(z)/chunk_size))
			st.add_vertex(Vector3(x, y, z))
	
	var vert_row = chunk_size + 3
	for z in range(chunk_size):
		for x in range(chunk_size):
			var i = (z + 1) * vert_row + (x + 1)
			st.add_index(i); st.add_index(i + 1); st.add_index(i + vert_row)
			st.add_index(i + 1); st.add_index(i + vert_row + 1); st.add_index(i + vert_row)

	st.generate_normals()
	var mesh = st.commit()

	# Scatter Logic (Picking Scenes instead of Meshes)
	var scatter_results = []
	for z in range(0, chunk_size, 4): # Increased step for Scene performance
		for x in range(0, chunk_size, 4):
			var world_x = x_off + x
			var world_z = z_off + z
			var d = density_noise.get_noise_2d(world_x, world_z)
			
			if d > scatter_density:
				var y = terrain_noise.get_noise_2d(world_x, world_z) * height_scale
				var pos = Vector3(x, y, z)
				var rot = randf() * TAU
				@warning_ignore("shadowed_variable_base_class")
				var scale = randf_range(0.8, 1.2)
				
				var chosen_scene = tree_scenes.pick_random() if d > 0.4 else bush_scenes.pick_random()
				if chosen_scene:
					scatter_results.append({"scene": chosen_scene, "pos": pos, "rot": rot, "scale": scale})
	
	call_deferred("finalize_chunk", coord, mesh, x_off, z_off, scatter_results)

# --- MAIN THREAD ---
func finalize_chunk(coord: Vector2i, mesh: Mesh, x_f: float, z_f: float, scatter_data: Array):
	var mi = MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = terrain_material
	mi.position = Vector3(x_f, 0, z_f)
	add_child(mi)
	mi.create_trimesh_collision()
	chunks[coord] = mi
	
	# Instantiate each tree/bush as a unique node
	for item in scatter_data:
		var instance = item.scene.instantiate()
		mi.add_child(instance)
		instance.position = item.pos
		instance.rotation.y = item.rot
		instance.scale = Vector3.ONE * item.scale
