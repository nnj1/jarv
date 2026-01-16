@tool
extends EditorScenePostImport

# This is the entry point Godot calls automatically
func _post_import(scene: Node) -> Object:
	_process_node(scene, scene)
	return scene

func _process_node(node: Node, root: Node):
	if node is MeshInstance3D:
		_create_collision(node, root)
	
	# Continue iterating through all children
	for child in node.get_children():
		_process_node(child, root)

func _create_collision(mesh_node: MeshInstance3D, root: Node):
	# 1. Generate the collision nodes (StaticBody3D and CollisionShape3D)
	# This helper creates them as children of the MeshInstance
	mesh_node.create_trimesh_collision()
	
	# 2. We must find the newly created StaticBody3D to configure it
	for child in mesh_node.get_children():
		if child is StaticBody3D:
			# Set the owner to the scene root so it actually saves to the .scn file
			child.owner = root
			# Also set the owner for the CollisionShape3D inside the StaticBody
			for grand_child in child.get_children():
				if grand_child is CollisionShape3D:
					grand_child.owner = root
			
			# OPTIONAL: Performance optimizations for giant maps
			# Layer 1 = General, Layer 2 = Environment/Ground
			child.collision_layer = 1 
			child.collision_mask = 0 # Static ground doesn't need to 'detect' anything
