extends Node2D

var modal_name:String
var modal_desc:String
var target_node
var target_mesh: MeshInstance3D

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	
	# make modal spawn at mouse position
	self.global_position = get_global_mouse_position()
	
	# change modal title
	$Panel/VBoxContainer/modal_name.text = modal_name
	$Panel/VBoxContainer/modal_desc.text = modal_desc
	
	# make mouse movable
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func prepare(given_modal_name:String = 'default_modal', given_modal_desc:String = 'default_modal_desc', given_node:Variant = null, given_mesh:MeshInstance3D = null):
	modal_name = given_modal_name
	modal_desc = given_modal_desc
	target_node = given_node
	target_mesh = given_mesh
	
	var	button_container = $Panel/VBoxContainer/HBoxContainer/VBoxContainer/VBoxContainer

	# show the texture swap menu
	if target_mesh:
		var texture_files = GlobalVars.get_files_recursive('res://assets/free_gmc_motorhome_reimagined_low_poly/swap_textures/', ['.tres'])
		for texture_file in texture_files:	
			button_container.add_child(create_custom_button(texture_file))


func create_custom_button(text_given:String = 'default string'):
	# 1. Create the instance
	var new_btn = Button.new()
	
	# 2. Set the text
	new_btn.text = text_given
	
	# 3. Set Horizontal Expand + Fill
	# SIZE_EXPAND_FILL is a combination of SIZE_EXPAND and SIZE_FILL
	new_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	
	# 4. Connect the signal (Godot 4 syntax)
	# Connects 'pressed' to a function named '_on_button_pressed'
	# The method that runs when the button is clicked
	var press_function = func _on_button_pressed():
		var new_mat = load('res://assets/free_gmc_motorhome_reimagined_low_poly/swap_textures/' + text_given)
		target_mesh.set_surface_override_material(0, new_mat.duplicate(true))
		
	new_btn.pressed.connect(press_function)
	
	return new_btn


	
# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	pass

func _on_close_button_pressed() -> void:
	# return mouse capture
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	queue_free()

# for default texture button
func _on_button_pressed() -> void:
	if target_mesh:
		target_mesh.set_surface_override_material(0, null)
