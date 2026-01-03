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
@export var grass_scale: Vector2 = Vector2(0.5, 1.0) * 100
@export var min_solid_distance: float = 10.0 

@export_group("Noise Configuration")
@export var terrain_noise: FastNoiseLite = FastNoiseLite.new()
@export var density_noise: FastNoiseLite = FastNoiseLite.new()
@export var road_noise: FastNoiseLite = FastNoiseLite.new()

var asset_library = {"solid": [], "soft": []}
var grass_meshes: Array[Mesh] = [] # Pre-extracted meshes for MultiMesh
var grass_textures: Array[Texture2D] = [] # pre extracted textures

var chunks = {} 
var terrain_material: ShaderMaterial
var player_spawn: Node3D
var player_node: Node3D
var rv_spawn: Node3D

func _ready():
	setup_noise()
	setup_terrain_material()
	
	player_spawn = get_node(player_spawn_path)
	rv_spawn = get_node(rv_spawn_path)
	
	# Load Assets and extract meshes for optimization
	_load_all_assets()
	
	var spawn_pos = find_road_center(Vector2.ZERO, 500)
	if player_spawn:
		player_spawn.global_position = Vector3(spawn_pos.x, road_height + 2.0, spawn_pos.y)
	if rv_spawn:
		rv_spawn.global_position = Vector3(spawn_pos.x, road_height + 2.0, spawn_pos.y + 10.0)
		rv_spawn.look_at(Vector3(spawn_pos.x, road_height + 2.0, spawn_pos.y - 10.0))

func _load_all_assets():
	asset_library["solid"].append_array(load_scenes_from_dir(tree_folder))
	asset_library["solid"].append_array(load_scenes_from_dir(rock_folder))
	asset_library["solid"].append_array(load_scenes_from_dir(log_folder))
	asset_library["solid"].append_array(load_scenes_from_dir(stump_folder))
	
	var grass_scenes = load_scenes_from_dir(grass_folder)
	asset_library["soft"].append_array(grass_scenes)
	
	# Pre-extract meshes from grass scenes for MultiMesh use
	for scene in grass_scenes:
		var temp = scene.instantiate()
		# Find the MeshInstance3D node first/
		var mesh_inst = _find_mesh_instance_recursive(temp)
		
		if mesh_inst:
			
			# 1. Store the Mesh resource from the node
			grass_meshes.append(mesh_inst.mesh)
			
			# 2. Get the material from the node (where get_active_material lives)
			var tex = null
			var mat = mesh_inst.get_active_material(0)
			
			# Fallback: if node material is null, check the mesh resource surface material
			if mat == null:
				mat = mesh_inst.mesh.surface_get_material(0)
				
			# 3. Extract the texture if it's a standard material
			if mat is StandardMaterial3D:
				tex = mat.albedo_texture
			elif mat is ShaderMaterial:
				# If it's already a shader, try to grab a texture parameter
				tex = mat.get_shader_parameter("albedo_texture")
				
			grass_textures.append(tex)
		
		temp.queue_free()

# Improved recursive search
func _find_mesh_instance_recursive(node: Node) -> MeshInstance3D:
	# If this node is a MeshInstance3D, we found it!
	if node is MeshInstance3D:
		return node
	
	# Otherwise, check all children of this node
	for child in node.get_children():
		var found = _find_mesh_instance_recursive(child)
		if found:
			return found
			
	# Return null if no MeshInstance3D exists in this branch
	return null

func setup_noise():
	terrain_noise.seed = 1337
	terrain_noise.frequency = 0.006 
	density_noise.seed = 1338
	density_noise.frequency = 0.01 
	road_noise.seed = 999 
	road_noise.frequency = 0.003
	road_noise.noise_type = FastNoiseLite.TYPE_PERLIN

func find_road_center(near_pos: Vector2, search_range: int) -> Vector2:
	var best_pos = near_pos
	var min_val = 1000.0
	var step = 0.5 
	var x = near_pos.x - search_range
	while x < near_pos.x + search_range:
		var z = near_pos.y - search_range
		while z < near_pos.y + search_range:
			var val = abs(road_noise.get_noise_2d(x, z))
			if val < min_val:
				min_val = val
				best_pos = Vector2(x, z)
				if min_val < 0.001: return best_pos
			z += step
		x += step
	return best_pos

func load_scenes_from_dir(path: String) -> Array[PackedScene]:
	var arr: Array[PackedScene] = []
	if path == "": return arr
	var dir = DirAccess.open(path)
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if not dir.current_is_dir() and not file_name.ends_with(".import"):
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
	if not player_node:
		var player_path = 'entities/' + str(multiplayer.get_unique_id())
		if main_game_node.has_node(player_path):
			player_node = main_game_node.get_node(player_path)
	else:
		update_chunks()

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

	# 1. Generate Terrain Mesh
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
	
	# 2. Scatter Logic
	var solid_results = []
	var grass_transforms = []
	var rng = RandomNumberGenerator.new()
	rng.seed = hash(coord)

	# Solids (Trees/Rocks)
	for i in range(150):
		var rx = rng.randf_range(0, chunk_size)
		var rz = rng.randf_range(0, chunk_size)
		if abs(road_noise.get_noise_2d(x_off + rx, z_off + rz)) < (road_width + 0.05): continue
		if density_noise.get_noise_2d(x_off + rx, z_off + rz) > 0.1:
			var y = terrain_noise.get_noise_2d(x_off + rx, z_off + rz) * height_scale
			var pos = Vector3(rx, y, rz)
			var too_close = false
			for res in solid_results:
				if res.pos.distance_to(pos) < min_solid_distance:
					too_close = true; break
			if not too_close:
				solid_results.append({"scene": asset_library["solid"].pick_random(), "pos": pos, "rot": rng.randf() * TAU, "scale": rng.randf_range(tree_scale.x, tree_scale.y)})

	# Softs (MultiMesh Grass)
	for i in range(2500):
		var rx = rng.randf_range(0, chunk_size)
		var rz = rng.randf_range(0, chunk_size)
		if abs(road_noise.get_noise_2d(x_off + rx, z_off + rz)) < road_width: continue 
		if density_noise.get_noise_2d(x_off + rx, z_off + rz) > -0.2:
			var y = terrain_noise.get_noise_2d(x_off + rx, z_off + rz) * height_scale
			var this_basis = Basis().rotated(Vector3.RIGHT, -PI/2)
			this_basis = this_basis.rotated(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * rng.randf_range(grass_scale.x, grass_scale.y))
			grass_transforms.append(Transform3D(this_basis, Vector3(rx, y, rz)))

	call_deferred("finalize_chunk", coord, mesh, x_off, z_off, solid_results, grass_transforms)

func finalize_chunk(coord: Vector2i, mesh: Mesh, x_f: float, z_f: float, solid_data: Array, grass_data: Array):
	var mi = MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = terrain_material
	mi.position = Vector3(x_f, 0, z_f)
	add_child(mi)
	mi.create_trimesh_collision()
	chunks[coord] = mi

	# Create MultiMesh for Grass
	if grass_data.size() > 0 and grass_meshes.size() > 0:
		var mm_instance = MultiMeshInstance3D.new()
		var mm = MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_colors = false      # Optional: if you want unique colors
		mm.use_custom_data = false # Optional: for custom shader data
		var random_idx = randi() % grass_meshes.size()
		mm.mesh = grass_meshes[random_idx]
		mm.instance_count = grass_data.size()
		for i in range(grass_data.size()):
			mm.set_instance_transform(i, grass_data[i])
		mm_instance.multimesh = mm
		
		# Assign the texture from array 2 via the shader
		#var linked_tex = grass_textures[random_idx]
		#mm_instance.material_override = get_sway_material(linked_tex)
		
		# CULLING FIX: Tell Godot to calculate the boundary for the whole chunk
		# This prevents the grass from flickering out when you look away
		#mm_instance.extra_cull_margin = 10.0
		mm_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF # Major performance boost
		mm_instance.visibility_range_end = 60.0
		mi.add_child(mm_instance)

	# Instantiate Solids
	for item in solid_data:
		var instance = item.scene.instantiate()
		mi.add_child(instance)
		instance.position = item.pos
		instance.rotation.y = item.rot
		instance.scale = Vector3.ONE * item.scale
		_apply_performance_and_physics(instance)

func _apply_performance_and_physics(node: Node):
	if node is GeometryInstance3D:
		node.visibility_range_end = 100.0
		_create_static_collision_for_mesh(node)
	for child in node.get_children():
		_apply_performance_and_physics(child)

func _create_static_collision_for_mesh(mesh_node: MeshInstance3D):
	for child in mesh_node.get_children():
		if child is StaticBody3D: return
	var static_body = StaticBody3D.new()
	var collision_shape_node = CollisionShape3D.new()
	collision_shape_node.shape = mesh_node.mesh.create_trimesh_shape()
	mesh_node.add_child(static_body)
	static_body.add_child(collision_shape_node)
	
func get_sway_material(original_texture: Texture2D) -> ShaderMaterial:
	var mat = ShaderMaterial.new()
	var shader = Shader.new()
	
	shader.code = """
	shader_type spatial;
	render_mode cull_disabled, diffuse_lambert;

	uniform sampler2D grass_texture : source_color, filter_linear_mipmap;
	uniform vec3 base_tint : source_color = vec3(0.2, 0.4, 0.1);
	
	// Lower values for the subtle movement you requested
	uniform float wind_speed = 0.8;
	uniform float wind_strength = 0.15;
	uniform float wind_horizontal_scale = 0.02;
	uniform float tip_stiffness = 4.0; 

	void vertex() {
		// 1. Get world position for the wind wave math
		vec3 world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
		
		// 2. THE MASK FIX: 
		// If the grass jumps, it's because the root is moving.
		// Try (1.0 - UV.y) first. If it still jumps, change it to (UV.y).
		float tip_mask = pow(clamp(1.0 - UV.y, 0.0, 1.0), tip_stiffness);
		
		// 3. Horizontal Wind Math
		float time = TIME * wind_speed;
		float sway = sin(time + world_pos.x * wind_horizontal_scale + world_pos.z * wind_horizontal_scale);
		
		// 4. APPLY TO WORLD X/Z THEN CONVERT BACK TO LOCAL
		// This is the most stable way to prevent 'jumping' regardless of rotation.
		vec3 displacement = vec3(sway * wind_strength * tip_mask, 0.0, sway * wind_strength * tip_mask);
		
		// Convert the world displacement back into local vertex space
		VERTEX += (inverse(MODEL_MATRIX) * vec4(displacement, 0.0)).xyz;
	}

	void fragment() {
		vec4 tex = texture(grass_texture, UV);
		
		// Texture recovery: If texture is white or missing, use green tint
		if (tex.r > 0.95 && tex.g > 0.95 && tex.b > 0.95) {
			ALBEDO = base_tint;
		} else {
			ALBEDO = tex.rgb;
		}
		
		ALPHA = tex.a;
		ALPHA_SCISSOR_THRESHOLD = 0.5;
		ROUGHNESS = 0.8;
	}
	"""
	
	mat.shader = shader
	if original_texture:
		mat.set_shader_parameter("grass_texture", original_texture)
	
	return mat
