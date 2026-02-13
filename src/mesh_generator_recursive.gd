@tool
extends Node3D

@export var generate_collisions: bool = false:
	set(value):
		if value == true:
			do_generation()
		generate_collisions = false

func do_generation():
	var root = get_tree().edited_scene_root
	if not root:
		print("Error: Could not find edited_scene_root. Is the scene open?")
		return
	
	print("--- Starting Generation on: ", root.name, " ---")
	_process_node(self, root)
	print("--- Generation Finished ---")

func _process_node(current_node: Node, root: Node):
	if current_node is MeshInstance3D:
		if not _has_static_body(current_node):
			# Create the collision
			current_node.create_trimesh_collision()
			
			# The collision helper creates a StaticBody3D as the LAST child
			var static_body = current_node.get_child(current_node.get_child_count() - 1)
			
			if static_body is StaticBody3D:
				# CRITICAL: This makes it show up in the Scene Tree
				_set_owner_recursive(static_body, root)
				print("Successfully created collision for: ", current_node.name)
	
	for child in current_node.get_children():
		_process_node(child, root)

func _has_static_body(node: Node) -> bool:
	for child in node.get_children():
		if child is StaticBody3D: return true
	return false

func _set_owner_recursive(node: Node, root: Node):
	node.owner = root
	for child in node.get_children():
		child.owner = root # Ensure the CollisionShape3D child is also owned
