extends CharacterBody2D

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

func _physics_process(delta: float) -> void:
	self.velocity += get_gravity() * delta
	if Input.is_action_pressed("up"):
		self.velocity += Vector2(0, -100)
	if Input.is_action_pressed("left"):
		self.velocity += Vector2(-10, 0)
	if Input.is_action_pressed("right"):
		self.velocity += Vector2(10, 0)
	move_and_slide()
