extends Node3D


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	pass

func _enter_tree():
	print("Node ", name, " entered tree. Authority: ", is_multiplayer_authority(), " ID: ", multiplayer.get_unique_id())

func _exit_tree():
	print("Node ", name, " exiting tree.")
