extends CharacterBody2D

class_name Crystal

@export var baseHorizontalSpeed := 300
@export var horizonalAirSpeed := 100
@export var jumpStrength := -500
@export var horizontalRandomRange := 75

var horizontalSpeed: float

static var burst_speed_x := 150.0
static var burst_speed_y := Vector2(200, 350)

@onready var playerNode: Player = get_tree().get_first_node_in_group("player")
# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	$AnimatedSprite2D.play("idle")
	$PlayerSensor.body_entered.connect(self._on_entered)
	horizontalSpeed=randf_range(baseHorizontalSpeed-horizontalRandomRange, baseHorizontalSpeed+horizontalRandomRange)


func _physics_process(delta: float) -> void:
	var ai_direction: float = _do_horizontal(delta)
	_do_gravity(delta, ai_direction)
	move_and_slide()

func _do_horizontal(delta: float) -> float:
	var horizontalDeviation := self.playerNode.position.x - self.position.x
	var ai_direction := -1 if horizontalDeviation > 0 else 1
	if is_on_floor():
		self.velocity.x = ai_direction * horizontalSpeed
	if is_on_wall() and is_on_floor():
		self.velocity.y = jumpStrength
	return ai_direction

func _do_gravity(delta: float, ai_direction: float) -> void:
	if not is_on_floor():
		self.velocity += get_gravity() * delta
		self.velocity.x = ai_direction * self.horizonalAirSpeed
		

func _on_entered(body: Node2D) -> void:
	if body is Player:
		body.add_crystal()
		self.queue_free()

# This is a helper function for geting you some random burst velocity
# Helpful when you want a crystal to appear with some trouble
static func get_burst_velocity() -> Vector2:
	return Vector2(
			randf_range(-burst_speed_x, burst_speed_x),
			-randf_range(burst_speed_y.x, burst_speed_y.y))
