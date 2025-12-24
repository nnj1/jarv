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
	
# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.
	
func _physics_process(_delta: float) -> void:
	if holding_player:
		self.global_position = holding_player.get_node('weapons/hand/grab_position').global_position
		self.global_rotation = holding_player.get_node('weapons/hand/grab_position').global_rotation

func drop() -> void:
	holding_player.entity_held = null
	holding_player = null

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	pass
