extends Node3D

class_name GenericMap

@onready var main_game_node = get_tree().get_root().get_node('Node3D')

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	if not multiplayer.is_server(): return 
	
	# load in the 100 mats throughout the map
	for spawn_pos in GlobalVars.generate_random_points($rv_spawn_point.global_position, 1000, 100, 50):
		var mat_scene = preload('res://scenes/entities/mat.tscn').instantiate()
		mat_scene.setup()
		mat_scene.prepare()
		mat_scene.position = spawn_pos # once added it's local position will become global position
		main_game_node.get_node('entities').call_deferred("add_child", mat_scene, true)

	# load in the 50 bears throughout the map
	for spawn_pos in GlobalVars.generate_random_points($rv_spawn_point.global_position, 1000, 50, 50):
		var scene_instance = load('res://scenes/entities/bear.tscn').instantiate()
		scene_instance.name = "bear_" + str(scene_instance.get_instance_id())
		scene_instance.home_position = spawn_pos
		scene_instance.rotation.y = randf_range(0, 2*PI)
		main_game_node.get_node('entities').call_deferred("add_child", scene_instance, true)
		main_game_node.global_teleport(scene_instance, spawn_pos)
