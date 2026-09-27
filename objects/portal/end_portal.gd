extends Area2D


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	self.body_entered.connect(self._on_body_entered)


func _on_body_entered(node: Node2D) -> void:
	var player := node as Player
	if player != null:
		get_tree().change_scene_to_file("res://menus/game_won/GameWon.tscn")
