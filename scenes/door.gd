extends StaticBody3D

const is_interactable: bool = true
const is_pickable: bool = false
const custom_interact_message: String = 'Press E to use door'

func interact(player_node: Node3D) -> void:
	print(str(player_node) + ' used the door.')
		
# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	pass
