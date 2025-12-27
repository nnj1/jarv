extends Area3D

const is_interactable: bool = true
const is_pickable: bool = false
const custom_interact_message: String = 'Press E to drive'

func interact(player_node: Node3D) -> void:
	print(str(player_node) + ' interacted with drivers seat.')
	# first see if the player is already driving, so they can stop
	if get_parent().driver_player_id == str(player_node.multiplayer.get_unique_id()):
		player_node.stop_driving()
		print(str(player_node) + ' stopped driving.')
	# then check to see if someone is driving
	elif get_parent().driver_player_id:
		print(str(player_node) + ' tried driving but someone else is.')
	elif not player_node.is_driving:
		player_node.start_driving(self)
		print(str(player_node) + ' started driving.')
		
# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	pass
