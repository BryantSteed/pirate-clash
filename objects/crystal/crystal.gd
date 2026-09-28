extends CharacterBody2D

@export var horizontalSpeed := 100

@onready var playerNode: Player = get_tree().get_first_node_in_group("player")
# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	$AnimatedSprite2D.play("idle")
	$PlayerSensor.body_entered.connect(self._on_entered)


func _physics_process(delta: float) -> void:
	_do_gravity(delta)
	_do_horizontal(delta)
	move_and_slide()

func _do_horizontal(delta: float) -> void:
	if not is_on_floor():
		return
	var horizontalDeviation := self.playerNode.position.x - self.position.x
	if horizontalDeviation < 0:
		self.velocity.x = self.horizontalSpeed
	else:
		self.velocity.x = -self.horizontalSpeed

func _do_gravity(delta: float) -> void:
	if not is_on_floor():
		self.velocity += get_gravity() * delta

func _on_entered(body: Node2D) -> void:
	if body is Player:
		body.add_crystal()
		self.queue_free()
