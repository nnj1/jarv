extends RigidBody3D

# --- Node References ---
@onready var main_game_node = get_tree().get_root().get_node('Node3D')

# --- Constants & Variables ---
const is_interactable: bool = true
const is_pickable: bool = true
const custom_interact_message: String = 'Press E to pick up'

var holding_player: Node3D = null
var hand_node: Marker3D = null # Store the specific hand node

# --- Standard Loops ---

func _process(_delta: float) -> void:
	# If someone is holding this, match their hand's position/rotation perfectly
	if holding_player and hand_node:
		self.global_transform = hand_node.global_transform

# --- Interaction Logic ---
func interact(given_player_node) -> void:
	if given_player_node.is_multiplayer_authority():
		if given_player_node.weapons[given_player_node.weapon_index].name == 'hand':
			var player_id = given_player_node.multiplayer.get_unique_id()
			rpc_id(1, "server_request_pickup", player_id)

# --- Pickup Logic ---

@rpc("any_peer", "call_local", "reliable")
func server_request_pickup(given_player_id: int) -> void:
	if not multiplayer.is_server(): return
	sync_pickup.rpc(given_player_id)

@rpc("call_local", "reliable")
func sync_pickup(given_player_id: int) -> void:
	var player_path = 'entities/' + str(given_player_id)
	var given_player_node = main_game_node.get_node_or_null(player_path)
	
	if not given_player_node: return

	holding_player = given_player_node
	given_player_node.entity_held = self
	
	# Find the hand node once and cache it
	hand_node = holding_player.get_node('weapons/hand/grab_position')
	
	stop_item_highlight()
	
	# Physics: Disable physics entirely so it doesn't fall or collide
	self.freeze = true
	self.collision_layer = 0
	self.collision_mask = 0

# --- Drop Logic ---

@rpc("any_peer", "call_local", "reliable")
func drop() -> void:
	if not multiplayer.is_server():
		rpc_id(1, "drop")
		return
	sync_drop.rpc()

@rpc("call_local", "reliable")
func sync_drop() -> void:
	if not holding_player: return
	
	# Capture current hand position before letting go
	var final_transform = self.global_transform
	
	holding_player.entity_held = null
	holding_player = null
	hand_node = null
	
	# Restore physics
	self.global_transform = final_transform
	self.freeze = false
	self.collision_layer = 1
	self.collision_mask = 1
	
	# Server-only impulse
	if multiplayer.is_server():
		self.apply_central_impulse(-global_transform.basis.z * 3.0)
	
	start_item_highlight()

# --- Visuals ---

func start_item_highlight() -> void:
	var mesh_path = 'Sketchfab_Scene/Sketchfab_model/fuel_can_fbx/RootNode/fuel_can/fuel_can_fuel_can_0'
	var mesh_instance = get_node_or_null(mesh_path)
	if mesh_instance:
		var base_mat = mesh_instance.get_active_material(0)
		if base_mat and base_mat.next_pass:
			base_mat.next_pass.set_shader_parameter("cycle_interval", 1.0)
	
func stop_item_highlight() -> void:
	var mesh_path = 'Sketchfab_Scene/Sketchfab_model/fuel_can_fbx/RootNode/fuel_can/fuel_can_fuel_can_0'
	var mesh_instance = get_node_or_null(mesh_path)
	if mesh_instance:
		var base_mat = mesh_instance.get_active_material(0)
		if base_mat and base_mat.next_pass:
			base_mat.next_pass.set_shader_parameter("cycle_interval", 0.0)

func _ready() -> void:
	if multiplayer.is_server():
		self.set_multiplayer_authority(1)
