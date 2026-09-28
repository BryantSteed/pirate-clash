extends CharacterBody2D


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	$AnimatedSprite2D.play("idle")
	$PlayerSensor.body_entered.connect(self._on_entered)


@export var ground_friction := 600.0     # how fast a launched crystal stops sliding once it lands (px/s²)


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		self.velocity += get_gravity() * delta
	else:
		self.velocity.x = move_toward(self.velocity.x, 0, ground_friction * delta)
	move_and_slide()

func _on_entered(body: Node2D) -> void:
	if body is Player:
		body.add_crystal()
		self.queue_free()
