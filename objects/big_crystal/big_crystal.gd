extends Area2D

@export var num_crystal_split: int = 5

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	self.area_entered.connect(self._on_area_entered)


func _on_area_entered(node: Node2D) -> void:
	print("it got entered!")
	var playerBullet := node as PlayerBullet
	if playerBullet == null:
		print("it wasnt a player bullet though")
		return
	var parent_node := get_parent()
	var crystalPackedScene := load("res://objects/crystal/crystal.tscn")
	for i in range(num_crystal_split):
		var small_crystal = crystalPackedScene.instantiate()
		small_crystal.position = self.position
		parent_node.add_child(small_crystal)
	self.queue_free()
