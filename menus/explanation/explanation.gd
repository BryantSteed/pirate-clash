extends Node


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.

func _unhandled_key_input(event: InputEvent) -> void:
	get_tree().change_scene_to_file("res://levels/pirate_cave/pirate_cave.tscn")

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action("shoot"):
		get_tree().change_scene_to_file("res://levels/pirate_cave/pirate_cave.tscn")
