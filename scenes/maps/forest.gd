extends Node3D

@onready var main_game_node = get_tree().get_root().get_node('Node3D')

@export_group("Spawn Settings")
@export var player_spawn_path: NodePath = "player_spawn_point"
@export var rv_spawn_path: NodePath = "rv_spawn_point"

@export_group("Terrain Settings")
@export var chunk_size: int = 32
@export var chunk_radius: int = 4
@export var height_scale: float = 5.0 

@export_group("Road Settings")
@export var road_width: float = 0.04   
@export var road_smoothness: float = 0.02 
@export var road_height: float = 0.0    

@export_group("Asset Folders")
@export_dir var tree_folder: String = "res://assets/Ultimate Nature Pack by Quaternius/FBX/trees/"
@export_dir var rock_folder: String = "res://assets/Ultimate Nature Pack by Quaternius/FBX/rocks/"
@export_dir var log_folder: String = "res://assets/Ultimate Nature Pack by Quaternius/FBX/logs/"
@export_dir var stump_folder: String = "res://assets/Ultimate Nature Pack by Quaternius/FBX/stumps/"
@export_dir var grass_folder: String = "res://assets/Ultimate Nature Pack by Quaternius/FBX/grass/"

@export_group("Scale Settings")
@export var tree_scale: Vector2 = Vector2(4.0, 5.0)
@export var rock_scale: Vector2 = Vector2(2.0, 4.0)
@export var log_scale: Vector2 = Vector2(3.0, 4.0)
@export var stump_scale: Vector2 = Vector2(3.0, 4.0)
@export var grass_scale: Vector2 = Vector2(0.5, 1.0)
@export var min_solid_distance: float = 10.0 

@export_group("Noise Configuration")
@export var terrain_noise: FastNoiseLite = FastNoiseLite.new()
@export var density_noise: FastNoiseLite = FastNoiseLite.new()
@export var road_noise: FastNoiseLite = FastNoiseLite.new()

var asset_library = {"solid": [], "soft": []}
var chunks = {} 
var terrain_material: ShaderMaterial
var player_spawn: Node3D
var player_node: Node3D
var rv_spawn: Node3D

func _ready():
	# 1. Initialize Noise first so we can calculate positions
	setup_noise()
	setup_terrain_material()
	
	# 2. Get references
	player_spawn = get_node(player_spawn_path)
	rv_spawn = get_node(rv_spawn_path)
	player_node = main_game_node.get_node('entities/' + str(multiplayer.get_unique_id()))
	
	# 3. Find road center and spawn entities
	var spawn_pos = find_road_center(Vector2.ZERO, 500)
	if player_spawn:
		player_spawn.global_position = Vector3(spawn_pos.x, road_height + 2.0, spawn_pos.y)
	if rv_spawn:
		# Place RV slightly behind player_spawn
		rv_spawn.global_position = Vector3(spawn_pos.x, road_height + 2.0, spawn_pos.y + 10.0)
		rv_spawn.look_at(Vector3(spawn_pos.x, road_height + 2.0, spawn_pos.y - 10.0))

	# 4. Load Assets
	asset_library["solid"].append_array(load_scenes_from_dir(tree_folder))
	asset_library["solid"].append_array(load_scenes_from_dir(rock_folder))
	asset_library["solid"].append_array(load_scenes_from_dir(log_folder))
	asset_library["solid"].append_array(load_scenes_from_dir(stump_folder))
	asset_library["soft"].append_array(load_scenes_from_dir(grass_folder))

func find_road_center(near_pos: Vector2, search_range: int) -> Vector2:
	var best_pos = near_pos
	var min_val = 1000.0
	
	# We use a step of 0.5 to ensure we don't 'jump over' a narrow road
	var step = 0.5 
	
	# search_range is now used to define the bounds
	var start_x = near_pos.x - search_range
	var end_x = near_pos.x + search_range
	var start_z = near_pos.y - search_range
	var end_z = near_pos.y + search_range
	
	var x = start_x
	while x < end_x:
		var z = start_z
		while z < end_z:
			# Get the absolute noise value
			var val = abs(road_noise.get_noise_2d(x, z))
			
			if val < min_val:
				min_val = val
				best_pos = Vector2(x, z)
				
				# Optimization: If we are basically on the center line, stop searching
				if min_val < 0.001: 
					return best_pos
			z += step
		x += step
		
	return best_pos
	
func setup_noise():
	terrain_noise.seed = randi()
	terrain_noise.frequency = 0.006 
	terrain_noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	terrain_noise.fractal_octaves = 3
	
	density_noise.seed = randi() + 1
	density_noise.frequency = 0.01 
	
	road_noise.seed = 999 
	road_noise.frequency = 0.003
	road_noise.noise_type = FastNoiseLite.TYPE_PERLIN

func load_scenes_from_dir(path: String) -> Array[PackedScene]:
	var arr: Array[PackedScene] = []
	if path == "" or path == null: return arr
	var dir = DirAccess.open(path)
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if not dir.current_is_dir():
				var ext = file_name.get_extension().to_lower()
				if ext in ["blend", "tscn", "fbx", "gltf", "glb"]:
					var scene = load(path + "/" + file_name)
					if scene is PackedScene: arr.append(scene)
			file_name = dir.get_next()
	return arr

func setup_terrain_material():
	var shader = Shader.new()
	shader.code = """
	shader_type spatial;
	varying float world_height;
	varying float road_factor;
	void vertex() { 
		world_height = (MODEL_MATRIX * vec4(VERTEX, 1.0)).y;
		road_factor = UV2.x; 
	}
	void fragment() {
		vec3 sand = vec3(0.76, 0.70, 0.50);
		vec3 grass = vec3(0.25, 0.40, 0.15);
		vec3 road_color = vec3(0.15, 0.15, 0.16);
		vec3 base_col = mix(sand, grass, smoothstep(1.0, 3.5, world_height));
		ALBEDO = mix(base_col, road_color, road_factor);
		ROUGHNESS = 0.8;
	}"""
	terrain_material = ShaderMaterial.new()
	terrain_material.shader = shader

func _process(_delta):
	if player_node: update_chunks()

func update_chunks():
	var p_pos = player_node.global_position
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
		if coord.distance_to(current_coord) > chunk_radius + 1: to_remove.append(coord)
	for coord in to_remove:
		if chunks[coord]: chunks[coord].queue_free()
		chunks.erase(coord)

func create_chunk_data(coord: Vector2i):
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var x_off = coord.x * chunk_size
	var z_off = coord.y * chunk_size

	for z in range(-1, chunk_size + 2):
		for x in range(-1, chunk_size + 2):
			var world_x = x_off + x
			var world_z = z_off + z
			var r_val = abs(road_noise.get_noise_2d(world_x, world_z))
			var is_road = clamp(inverse_lerp(road_width, road_width - road_smoothness, r_val), 0.0, 1.0)
			var y = terrain_noise.get_noise_2d(world_x, world_z) * height_scale
			y = lerp(y, road_height, is_road) 
			st.set_uv(Vector2(float(x)/chunk_size, float(z)/chunk_size))
			st.set_uv2(Vector2(is_road, 0)) 
			st.add_vertex(Vector3(x, y, z))
	
	var vert_row = chunk_size + 3
	for z in range(chunk_size):
		for x in range(chunk_size):
			var i = (z + 1) * vert_row + (x + 1)
			st.add_index(i); st.add_index(i + 1); st.add_index(i + vert_row)
			st.add_index(i + 1); st.add_index(i + vert_row + 1); st.add_index(i + vert_row)

	st.generate_normals()
	var mesh = st.commit()
	var scatter_results = []
	var rng = RandomNumberGenerator.new()
	rng.seed = hash(coord)

	for i in range(400):
		var rx = rng.randf_range(0, chunk_size)
		var rz = rng.randf_range(0, chunk_size)
		if abs(road_noise.get_noise_2d(x_off + rx, z_off + rz)) < (road_width + 0.02): continue
		var d = density_noise.get_noise_2d(x_off + rx, z_off + rz)
		if d > 0.0:
			var y = (terrain_noise.get_noise_2d(x_off + rx, z_off + rz) * height_scale)
			var pos = Vector3(rx, y, rz)
			var too_close = false
			for res in scatter_results:
				if res.is_solid and res.pos.distance_to(pos) < min_solid_distance:
					too_close = true
					break
			if not too_close:
				var scene = asset_library["solid"].pick_random()
				var s_path = scene.resource_path.to_lower()
				var final_scale = 1.0
				if "tree" in s_path: final_scale = rng.randf_range(tree_scale.x, tree_scale.y)
				elif "rock" in s_path: final_scale = rng.randf_range(rock_scale.x, rock_scale.y)
				elif "log" in s_path: final_scale = rng.randf_range(log_scale.x, log_scale.y)
				elif "stump" in s_path: final_scale = rng.randf_range(stump_scale.x, stump_scale.y)
				scatter_results.append({"scene": scene, "pos": pos - Vector3(0,0.1,0), "rot": rng.randf() * TAU, "scale": final_scale, "is_solid": true})

	for i in range(1500):
		var rx = rng.randf_range(0, chunk_size)
		var rz = rng.randf_range(0, chunk_size)
		if abs(road_noise.get_noise_2d(x_off + rx, z_off + rz)) < road_width: continue 
		var d = density_noise.get_noise_2d(x_off + rx, z_off + rz)
		if d > -0.2:
			var y = terrain_noise.get_noise_2d(x_off + rx, z_off + rz) * height_scale
			scatter_results.append({"scene": asset_library["soft"].pick_random(), "pos": Vector3(rx, y, rz), "rot": rng.randf() * TAU, "scale": rng.randf_range(grass_scale.x, grass_scale.y), "is_solid": false})

	call_deferred("finalize_chunk", coord, mesh, x_off, z_off, scatter_results)

func finalize_chunk(coord: Vector2i, mesh: Mesh, x_f: float, z_f: float, scatter_data: Array):
	var mi = MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = terrain_material
	mi.position = Vector3(x_f, 0, z_f)
	add_child(mi)
	mi.create_trimesh_collision()
	var body = mi.get_child(0) as StaticBody3D
	if body: body.collision_layer = 1
	chunks[coord] = mi
	for item in scatter_data:
		var instance = item.scene.instantiate()
		mi.add_child(instance)
		instance.position = item.pos
		instance.rotation.y = item.rot
		instance.scale = Vector3.ONE * item.scale
		_apply_performance_and_physics(instance, item.is_solid)

func _apply_performance_and_physics(node: Node, is_solid: bool):
	if node is GeometryInstance3D:
		if not is_solid: node.visibility_range_end = 80.0 
		if is_solid:
			_create_static_collision_for_mesh(node)
	if node is StaticBody3D: 
		node.collision_layer = 1 if is_solid else 0 
		node.collision_mask = 1
	for child in node.get_children():
		_apply_performance_and_physics(child, is_solid)

func _create_static_collision_for_mesh(mesh_node: MeshInstance3D):
	# 1. Create the StaticBody3D
	var static_body = StaticBody3D.new()
	# Optional: Set layers programmatically
	static_body.set_collision_layer_value(1, true)
	static_body.set_collision_mask_value(1, true)
	
	# 2. Create the CollisionShape3D node
	var collision_shape_node = CollisionShape3D.new()
	
	# 3. Generate the Trimesh Shape from the actual Mesh resource
	var trimesh_shape = mesh_node.mesh.create_trimesh_shape()
	collision_shape_node.shape = trimesh_shape
	
	# 4. Assembly: Add body to scene, then shape to body
	# Usually, you want the body to be a sibling or parent of the mesh
	# In this case, we'll strangely make it a child of the mesh
	mesh_node.add_child(static_body)
	static_body.add_child(collision_shape_node)
	
	# 5. Match the transform (very important!)
	# This ensures the collision box is exactly where the mesh is
	static_body.global_transform = mesh_node.global_transform
