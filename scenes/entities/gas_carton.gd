extends RigidBody3D

const is_interactable: bool = true
const is_pickable: bool = true
var holding_player: Node3D = null

const custom_interact_message: String = 'Press E to pick up'

func interact(given_player_node) -> void:
	if given_player_node.weapons[given_player_node.weapon_index].name == 'hand':
		print(str(given_player_node) + ' picked up the fuel cannister.')
		holding_player = given_player_node
		given_player_node.entity_held = self
		stop_item_highlight()
	
# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.
	
func start_item_highlight() -> void:
	var mesh_instance = get_node('Sketchfab_Scene/Sketchfab_model/fuel_can_fbx/RootNode/fuel_can/fuel_can_fuel_can_0')
	var base_mat = mesh_instance.get_active_material(0)
	#base_mat = base_mat.duplicate()
	mesh_instance.set_surface_override_material(0, base_mat)
	#base_mat.next_pass = base_mat.next_pass.duplicate()
	base_mat.next_pass.set_shader_parameter("cycle_interval", 1.0)
	
func stop_item_highlight() -> void:
	var mesh_instance = get_node('Sketchfab_Scene/Sketchfab_model/fuel_can_fbx/RootNode/fuel_can/fuel_can_fuel_can_0')
	var base_mat = mesh_instance.get_active_material(0)
	#base_mat = base_mat.duplicate()
	mesh_instance.set_surface_override_material(0, base_mat)
	#base_mat.next_pass = base_mat.next_pass.duplicate()
	base_mat.next_pass.set_shader_parameter("cycle_interval", 0.0)

func _physics_process(_delta: float) -> void:
	if holding_player:
		self.global_position = holding_player.get_node('weapons/hand/grab_position').global_position
		self.global_rotation = holding_player.get_node('weapons/hand/grab_position').global_rotation

func drop() -> void:
	holding_player.entity_held = null
	holding_player = null
	start_item_highlight()

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	pass
