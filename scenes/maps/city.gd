extends Node3D
@onready var main_game_node = get_tree().get_root().get_node('Node3D')

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	if not multiplayer.is_server(): return 
	
	# load in the 100s throughout the city
	for spawn_pos in GlobalVars.generate_random_points($rv_spawn_point.global_position, 1000, 100, 50):
		var mat_scene = preload('res://scenes/entities/mat.tscn').instantiate()
		mat_scene.setup()
		mat_scene.prepare()
		mat_scene.position = spawn_pos # once added it's local position will become global position
		main_game_node.get_node('entities').call_deferred("add_child", mat_scene, true)

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	pass
