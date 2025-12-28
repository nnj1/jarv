extends RigidBody3D

# --- Node References ---
@onready var main_game_node = get_tree().get_root().get_node('Node3D')

# --- Constants & Variables ---
const is_interactable: bool = true
const is_pickable: bool = true
const custom_interact_message: String = 'Press E to pick up'

var holding_player: Node3D = null

# --- Interaction Logic ---
func interact(given_player_node) -> void:
	# Even if we don't change authority, only the local player 
	# should trigger the initial request to the server.
	if given_player_node.is_multiplayer_authority():
		if given_player_node.weapons[given_player_node.weapon_index].name == 'hand':
			var player_id = given_player_node.multiplayer.get_unique_id()
			rpc_id(1, "server_request_pickup", player_id)

# --- Pickup Logic ---

@rpc("any_peer", "call_local", "reliable")
func server_request_pickup(given_player_id: int) -> void:
	# Server validates the request
	if not multiplayer.is_server(): return
	
	# Server broadcasts to everyone to move the canister
	sync_pickup.rpc(given_player_id)

@rpc("call_local", "reliable")
func sync_pickup(given_player_id: int) -> void:
	var player_path = 'entities/' + str(given_player_id)
	var given_player_node = main_game_node.get_node_or_null(player_path)
	
	if not given_player_node: return

	holding_player = given_player_node
	given_player_node.entity_held = self
	stop_item_highlight()
	
	# NOTE: We no longer call set_multiplayer_authority here.
	# Authority stays with the Server (1) for the entire lifecycle.
	
	# Physics: Disable so the server-owned object follows the hand
	self.freeze = true
	self.collision_layer = 0
	self.collision_mask = 0
	
	# Reparent to hand
	var grab_pos_node = holding_player.get_node('weapons/hand/grab_position')
	self.reparent.call_deferred(grab_pos_node)
	self.set_deferred("position", Vector3.ZERO)
	self.set_deferred("rotation", Vector3.ZERO)

# --- Drop Logic ---

@rpc("any_peer", "call_local", "reliable")
func drop() -> void:
	# Since Server always has authority, the client just 
	# asks the server to start the drop.
	if not multiplayer.is_server():
		rpc_id(1, "drop")
		return
	
	sync_drop.rpc()

@rpc("call_local", "reliable")
func sync_drop() -> void:
	if not holding_player: return
	
	var drop_transform = self.global_transform
	var world_root = main_game_node.get_node('entities')
	
	# Move back to the world
	self.reparent.call_deferred(world_root)
	_finish_drop.call_deferred(drop_transform)

func _finish_drop(old_transform: Transform3D) -> void:
	# Authority is already 1, so no change needed here.
	
	self.global_transform = old_transform
	self.freeze = false
	self.collision_layer = 1
	self.collision_mask = 1
	
	# Since authority is always Server, the Server applies the impulse
	if multiplayer.is_server():
		self.apply_central_impulse(-global_transform.basis.z * 3.0)
	
	if holding_player:
		holding_player.entity_held = null
	holding_player = null
	start_item_highlight()

# --- Visual Effects ---

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
	# Default everything to Server authority
	if multiplayer.is_server():
		self.set_multiplayer_authority(1)
