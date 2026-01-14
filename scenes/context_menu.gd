extends Node2D

var modal_name:String
var modal_desc:String
var target_node

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	
	# make modal spawn at mouse position
	self.global_position = get_global_mouse_position()
	
	# change modal title
	$Panel/VBoxContainer/modal_name.text = modal_name
	$Panel/VBoxContainer/modal_desc.text = modal_desc
	
	# make mouse movable
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func prepare(given_modal_name:String = 'default_modal', given_modal_desc:String = 'default_modal_desc', given_node:Variant = null):
	modal_name = given_modal_name
	modal_desc = given_modal_desc
	target_node = given_node
	
# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	pass

func _on_close_button_pressed() -> void:
	# return mouse capture
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	queue_free()
