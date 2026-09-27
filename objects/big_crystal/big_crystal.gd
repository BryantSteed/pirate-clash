extends Area2D

@export var num_crystal_split: int = 5

var is_broken: bool = false
# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	$AnimatedSprite2D.play("default")
	self.area_entered.connect(self._on_area_entered)


func _on_area_entered(node: Node2D) -> void:
	var playerBullet := node as PlayerBullet
	if playerBullet == null or is_broken:
		return
	$AnimatedSprite2D.play("broken")
	var parent_node := get_parent()
	var crystalPackedScene := load("res://objects/crystal/crystal.tscn")
	for i in range(num_crystal_split):
		var small_crystal = crystalPackedScene.instantiate()
		small_crystal.position = self.position
		parent_node.add_child(small_crystal)
