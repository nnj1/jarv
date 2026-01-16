extends Control

const IS_MODAL:bool = true
var dragging = false
var offset = Vector2.ZERO

@onready var main_game_node = get_tree().get_root().get_node('Node3D')

var modal_name:String
var modal_desc:String
var target_node = null
var target_mesh: MeshInstance3D = null
var data_contents:Dictionary

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	# close out any other open modals except for self
	for node in main_game_node.get_node('CanvasLayer').get_children():
		if 'IS_MODAL' in node and node != self:
			node.queue_free()
			
	# play open sound
	$openSound.play()
	
	# make player stop moving
	main_game_node.in_context_menu = true
	
	# make modal spawn at mouse position
	self.global_position = get_global_mouse_position()
	
	# change modal title
	$Panel/VBoxContainer/modal_name.text = modal_name
	$Panel/VBoxContainer/modal_desc.text = modal_desc
	
	# show the texture swap menu if a target mesh_was passed
	if target_mesh:
		prepare_texture_swap_tab()
		$Panel/VBoxContainer/TabContainer.set_tab_hidden(0, false)
	else:
		$Panel/VBoxContainer/TabContainer.set_tab_hidden(0, true)
	
	# show the data tab if there are data_content to show
	if data_contents:
		prepare_data_tab()
		$Panel/VBoxContainer/TabContainer.set_tab_hidden(1, false)
	else:
		$Panel/VBoxContainer/TabContainer.set_tab_hidden(1, true)
		
	
	# make mouse movable so user can interact
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

# if UI is called
func _input(event):
	if event.is_action_pressed("ui_cancel"):
		close_context_menu()

# Accepts all input variables and extracts useful data from passed in node
func prepare(given_modal_name:String = 'default_modal', given_modal_desc:String = 'default_modal_desc', given_node:Variant = null, given_mesh:MeshInstance3D = null):
	modal_name = given_modal_name
	modal_desc = given_modal_desc
	target_node = given_node
	target_mesh = given_mesh
	
	# if target node hsa a specific desc, override the existing one
	if target_node:
		if 'desc' in target_node:
			modal_desc = target_node.desc
	
	# if target node has a associated data structure you wanna display
	if target_node:
		if 'IS_RV' in target_node:
			data_contents = GameManager.rv_data
			
			
# DRAG AND DROP LOGIC FOR MODAL
func _gui_input(event):
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				# Start dragging and remember where we clicked relative to the Panel
				dragging = true
				offset = get_global_mouse_position() - global_position
			else:
				# Stop dragging when mouse is released
				dragging = false

func _process(_delta):
	if dragging:
		# Follow the mouse, maintaining the original click offset
		global_position = get_global_mouse_position() - offset
	
# FOR NODE DATA:
func prepare_data_tab():
	$Panel/VBoxContainer/TabContainer/Data.text = JSON.stringify(data_contents)
		 
# FOR TEXTURE SWAPPING
func prepare_texture_swap_tab():
	var	button_container = $'Panel/VBoxContainer/TabContainer/Change Skin/VBoxContainer/VBoxContainer'
	var preview_viewport = $'Panel/VBoxContainer/TabContainer/Change Skin/Panel/SubViewportContainer/SubViewport'
	
	var texture_files = GlobalVars.get_files_recursive('res://assets/free_gmc_motorhome_reimagined_low_poly/swap_textures/', ['.tres'])
	for texture_file in texture_files:	
		button_container.add_child(create_custom_button(texture_file))
	
	# show preview of the mesh preview
	# TODO: Make this better, scale the preview appropriately, rotate camera, etc
	var preview_mesh = target_mesh.duplicate(true)
	preview_viewport.add_child(preview_mesh)

# for other texture buttons
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

# for default texture button
func _on_button_pressed() -> void:
	if target_mesh:
		target_mesh.set_surface_override_material(0, null)

# CLOSE BUTTON
func _on_close_button_pressed() -> void:
	close_context_menu()
	
func close_context_menu():
	# return mouse capture
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	# let player walk again
	main_game_node.in_context_menu = false
	queue_free()
