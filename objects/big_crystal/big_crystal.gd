extends Area2D

const CrystalScene := preload("res://objects/crystal/crystal.tscn")

@export var num_crystal_split: int = 5
@export var burst_speed_x := 150.0           # max sideways launch speed of the small crystals
@export var burst_speed_y := Vector2(200, 350) # min/max upward launch speed

var is_broken: bool = false
# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	$AnimatedSprite2D.play("default")
	self.area_entered.connect(self._on_area_entered)


func _on_area_entered(node: Node2D) -> void:
	var playerBullet := node as PlayerBullet
	if playerBullet == null or is_broken:
		return
	self.is_broken = true
	$AnimatedSprite2D.play("broken")
	$BreakSound.play()
	var parent_node := get_parent()
	for i in range(num_crystal_split):
		var small_crystal := CrystalScene.instantiate() as CharacterBody2D
		small_crystal.position = self.position
		# Launch each one in a random upward direction so they spray out instead of piling up.
		small_crystal.velocity = Vector2(
			randf_range(-burst_speed_x, burst_speed_x),
			-randf_range(burst_speed_y.x, burst_speed_y.y))
		# Deferred: we're inside a physics callback, and adding bodies/areas mid-step errors.
		parent_node.add_child.call_deferred(small_crystal)
