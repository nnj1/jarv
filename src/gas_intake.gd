extends Area3D

const is_interactable: bool = true
const is_pickable: bool = false
const is_combinable: bool = true
const is_holdable: bool = true
var custom_interact_message: String = 'Press E to refuel'
var interacting_player = null

var fueling_status:bool = false

func interact(player_node: Node3D) -> void:
	if interacting_player == null:
		interacting_player = player_node
		print(str(player_node) + ' interacted with gas intake.')
		# logic for gas tank
		if player_node.entity_held:
			if 'ITEM_TYPE' in player_node.entity_held:
				if player_node.entity_held.ITEM_TYPE == 'GAS_CARTON':
					#rpc_id(1, 'request_refuel')
					fueling_status = true
					#player_node.entity_held.queue_free()
					
# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	if fueling_status:
		if not get_parent().get_node('refuelSound').playing:
			get_parent().get_node('refuelSound').play()
	else:
		get_parent().get_node('refuelSound').stop()
	
# should be called periodically
@rpc("any_peer","call_local","reliable")
func request_refuel(amount = 1000):
	if not multiplayer.is_server(): return
	print('Refueling the gas tank.')
	# TODO: make this logic more complex
	get_parent().refuel(amount)

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.

func _on_body_exited(body: Node3D) -> void:
	if body == interacting_player:
		fueling_status = false
		interacting_player = null
