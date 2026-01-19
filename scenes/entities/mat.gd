extends ItemBody

const barrel_textures_paths = [
	('res://assets/Holomind PSX Industrial Pack/Barrels/tex_barrel_1.jpg'),
	('res://assets/Holomind PSX Industrial Pack/Barrels/tex_barrel_2.jpg'),
	('res://assets/Holomind PSX Industrial Pack/Barrels/tex_barrel_3.jpg'),
	('res://assets/Holomind PSX Industrial Pack/Barrels/tex_barrel_4.jpg')
]
	
const descriptions = [
  "Jagged pieces of oxidized metal harvested from roadside wrecks. It’s brittle and ugly, but it can be smelted down or used for basic structural patches.",
  "A tangled mess of copper threads and frayed insulation. Essential for bypassing ignitions or restoring power to the RV's living quarters.",
  "Heavy-duty steel sheets that have been straightened and reinforced. Perfect for up-armor plating your vehicle to withstand highway hazards.",
  "A glowing, viscous byproduct found in industrial zones. Corrosive to the touch, but a vital ingredient for crafting potent fuels or makeshift explosives.",
  "Delicate silicon wafers salvaged from high-end electronics. These are the 'brains' required to upgrade your RV's GPS, autopilot, or engine management systems."
]

enum Type { RUSTY_SCRAP, WIRING_COMPONENTS, REFINED_PLATES, CHEMICAL_SLUDGE, PROCESSOR_CHIPS }
@export var current_type: Type

func prepare():
	#current_type = Type.values().pick_random()
	current_type = [Type.RUSTY_SCRAP, Type.REFINED_PLATES, Type.CHEMICAL_SLUDGE].pick_random()
	item_name = String(Type.find_key(current_type))
	item_description = descriptions[current_type]
	
	# if chemical sludge, choose a variable texture
	if current_type == Type.CHEMICAL_SLUDGE:
		var mat_override = $model/CHEMICAL_SLUDGE/mod_barrel_1/Cylinder.get_surface_override_material(0)
		mat_override.albedo_texture = load(barrel_textures_paths.pick_random())
		
	# make the correct mesh visible for the item
	for mesh in $model.get_children():
		mesh.hide()
	$model.get_node(Type.find_key(current_type)).show()
	
	
