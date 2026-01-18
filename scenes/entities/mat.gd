extends ItemBody

enum Type { RUSTY_SCRAP, WIRING_COMPONENTS, REFINED_PLATES, CHEMICAL_SLUDGE, PROCESSOR_CHIPS }
@export var current_type: Type

func prepare():
	#current_type = Type.values().pick_random()
	current_type = [Type.RUSTY_SCRAP, Type.REFINED_PLATES].pick_random()
	# make the correct mesh visible for the item
	for mesh in $model.get_children():
		mesh.hide()
	$model.get_node(Type.find_key(current_type)).show()
