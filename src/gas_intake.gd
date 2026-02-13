extends Area3D

const is_interactable: bool = true
const is_pickable: bool = false
const is_combinable: bool = true
var custom_interact_message: String = 'Press E to refuel'

func interact(player_node: Node3D) -> void:
	print(str(player_node) + ' interacted with gas intake.')
	# logic for gas tank
	if player_node.entity_held:
		if 'ITEM_TYPE' in player_node.entity_held:
			if player_node.entity_held.ITEM_TYPE == 'GAS_CARTON':
				print('Refueling the gas tank.')
				# TODO: make this logic more complex
				get_parent().refuel()
				# TODO: needs to be done across all clients probably
				player_node.entity_held.queue_free()
				
# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	pass
