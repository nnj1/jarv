extends Area3D

const is_interactable: bool = true
const is_pickable: bool = false
const is_combinable: bool = true
const is_holdable: bool = true
var custom_interact_message: String = 'Press E to refuel'
var interacting_player = null

var fueling_status:bool = false
var sync_timer: float = 0.0
const SYNC_INTERVAL: float = 1.0 # 1 second

func interact(player_node: Node3D) -> void:
	if not check_for_player_in_range(): 
		print('Player not close enough to fill gas')
		return # demand player be really close to refuel
	if interacting_player == null:
		interacting_player = player_node
		print(str(player_node) + ' interacted with gas intake.')
		# logic for gas tank
		if player_node.entity_held:
			if 'ITEM_TYPE' in player_node.entity_held:
				if player_node.entity_held.ITEM_TYPE == 'GAS_CARTON':
					fueling_status = true
					#player_node.entity_held.queue_free()
					
# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	if fueling_status:
		if not get_parent().get_node('refuelSound').playing:
			get_parent().get_node('refuelSound').play()
		
		sync_timer += delta
		if sync_timer >= SYNC_INTERVAL:
			# Call the RPC function
			rpc_id(1, 'request_refuel', 1)
			# Reset the timer (subtracting interval keeps it precise)
			sync_timer -= SYNC_INTERVAL
		
	else:
		get_parent().get_node('refuelSound').stop()
	
# should be called periodically
@rpc("any_peer","call_local","reliable")
func request_refuel(amount = 1000):
	if not multiplayer.is_server(): return
	print('Added ' + str(amount) + ' to gas tank.')
	# TODO: make this logic more complex
	get_parent().refuel(amount)

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.

func _on_body_exited(body: Node3D) -> void:
	print(str(body) + ' left fuel station.')
	if body == interacting_player:
		fueling_status = false
		interacting_player = null
		
func check_for_player_in_range():
	var bodies = get_overlapping_bodies()
	for body in bodies:
		if body is CharacterBody3D:
			if body.IS_PLAYER:
				if body.is_multiplayer_authority():
					print('Player is in range for interaction')
					return true
	return false
