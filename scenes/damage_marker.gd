extends Node3D

var value:int

func prepare(given_damage_value) -> void:
	self.text = str(int(given_damage_value))
	if given_damage_value > 75:
		self.modulate = Color.RED
	elif given_damage_value > 25:
		self.modulate = Color.ORANGE
	else:
		self.modulate = Color.WHITE
	
func _ready():
	burst_and_free()

func burst_and_free():
	# 1. Setup Random Direction
	var spread = 2.0 # How far it can drift sideways
	var random_x = randf_range(-spread, spread)
	var random_z = randf_range(-spread, spread)
	var target_height = position.y + 2.0
	
	# 2. Reset initial state
	self.scale = Vector3.ZERO
	self.modulate.a = 1.0
	
	var tween = create_tween().set_parallel(true)
	
	# 3. The Burst (Scale)
	tween.tween_property(self, "scale", Vector3.ONE * 2, 0.2)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	
	# 4. The Movement (Random arc)
	# Move to the random X/Z coordinates while floating up
	tween.tween_property(self, "position:x", position.x + random_x, 0.3)
	tween.tween_property(self, "position:z", position.z + random_z, 0.3)
	tween.tween_property(self, "position:y", target_height, 1.0)
	
	# 5. The Fade Out
	tween.tween_property(self, "modulate:a", 0.0, 0.5).set_delay(0.3)
	
	# 6. Delete
	tween.chain().tween_callback(queue_free)
