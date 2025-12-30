extends RigidBody3D

class_name ItemBody

# --- Data Properties ---
@export var item_name: String = 'default item name'
@export var item_description: String = 'default item description'

# --- Node References ---
@onready var main_game_node = get_tree().get_root().get_node('Node3D')
@onready var model_container = $model

# --- Interaction & Pickup Constants (need to be initiatized)---
@export var is_interactable: bool = true
@export var is_pickable: bool = true
@export var is_employable: bool = true
@export var is_consumable: bool = true
@export var custom_interact_message: String = 'Press E to pick up'

# --- State Variables ---
var holding_player: Node3D = null 
var hand_node: Marker3D = null 
@export var local_y_rotation: float = 0.0
var rotation_speed: float = 2.0

# --- Initialization & Model Loading ---

@warning_ignore("unused_parameter")
func setup(interactable: bool = true, pick:bool = true, employ: bool = false, consumable: bool = true, given_custom_interact_message = 'Press E to pick up') -> void:
	is_interactable = interactable
	is_pickable = pick
	is_employable = employ
	is_consumable = consumable
	custom_interact_message = given_custom_interact_message
		
# Will do something to the player stats if the player consumes the item
func consume(_given_player_node):
	# TODO: Do some player stat changes here based on item JSON
	pass

func _ready() -> void:
	# Only the server acts as the authority for physics and state
	if multiplayer.is_server():
		self.set_multiplayer_authority(1)

# --- Interaction & Movement Logic ---

@rpc("any_peer", "call_local", "unreliable")
func update_rotation_server(new_rotation: float) -> void:
	if multiplayer.is_server():
		local_y_rotation = new_rotation

func _process(delta: float) -> void:
	# While held, stick to the hand precisely
	if holding_player and hand_node:
		self.global_transform = hand_node.global_transform
		# apply any local y rotation
		rotate_object_local(Vector3.UP, local_y_rotation)
		
	# if you are the holding player, you can rotate the item with the reload key
	if holding_player:
		if holding_player.is_multiplayer_authority():
			if Input.is_action_pressed('reload'):
				# Calculate new rotation locally
				var increment = rotation_speed * delta
				local_y_rotation += increment
				# Tell the server the new value
				rpc_id(1, 'update_rotation_server', local_y_rotation)
			

func interact(given_player_node) -> void:
	# PRE-CHECK: If someone is already holding this, ignore interaction
	if holding_player != null:
		return
		
	if given_player_node.is_multiplayer_authority():
		if given_player_node.weapons[given_player_node.weapon_index].name == 'hand':
			var player_id = given_player_node.multiplayer.get_unique_id()
			# Ask server to pick this up
			rpc_id(1, "server_request_pickup", player_id)

@rpc("any_peer", "call_local", "reliable")
func server_request_pickup(given_player_id: int) -> void:
	if not multiplayer.is_server(): return
	
	# SERVER-SIDE GUARD: Deny if someone else picked it up during the network trip
	if holding_player != null:
		return
		
	sync_pickup.rpc(given_player_id)

@rpc("authority", "call_local", "reliable")
func sync_pickup(given_player_id: int) -> void:
	var player_path = 'entities/' + str(given_player_id)
	var given_player_node = main_game_node.get_node_or_null(player_path)
	if not given_player_node: return

	holding_player = given_player_node
	given_player_node.entity_held = self
	
	# Hand cache
	hand_node = holding_player.get_node('weapons/hand/grab_position')
	
	set_item_highlight(false)
	self.freeze = true

@rpc("any_peer", "call_local", "reliable")
func drop() -> void:
	if not multiplayer.is_server():
		rpc_id(1, "drop")
		return
	sync_drop.rpc()

@rpc("authority","call_local", "reliable")
func sync_drop() -> void:
	if not holding_player: return
	
	var final_transform = self.global_transform
	
	holding_player.entity_held = null
	hand_node = null
	
	self.global_transform = final_transform
	self.freeze = false
	
	if multiplayer.is_server():
		# Throw the item slightly forward in front of the player
		self.apply_central_impulse(-holding_player.global_transform.basis.z * 3.0)
	
	holding_player = null
	
	set_item_highlight(true)

# --- Generalized Visuals ---

func set_item_highlight(enabled: bool) -> void:
	var meshes = model_container.find_children("*", "MeshInstance3D", true)
	var value = 1.0 if enabled else 0.0
	
	# TODO: dynamically add item highlight shader, if not on
	
	for mesh_instance in meshes:
		# Apply highlight state to all material slots on the mesh
		for i in mesh_instance.get_surface_override_material_count():
			var mat = mesh_instance.get_active_material(i)
			if mat and mat.next_pass:
				mat.next_pass.set_shader_parameter("cycle_interval", value)
