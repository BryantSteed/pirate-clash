extends Node2D

var display_vec: Vector2
var gravitational_constant := Vector2(0, 100)
var jump_height := Vector2(0, 1000)
# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	self.display_vec = get_viewport_rect().size


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

func _physics_process(delta: float) -> void:
	_do_gravity(delta)
	if Input.is_action_pressed("up"):
		var up_deviation := delta * jump_height
		self.global_position -= up_deviation
	
func _do_gravity(delta: float) -> void:
	var scaled_deviation := delta * gravitational_constant
	var new_position := self.global_position + scaled_deviation
	if new_position.y > display_vec.y:
		#print("new position: ")
		#print(new_position.y)
		#print(display_vec.y)
		return
	
	self.global_position = new_position
