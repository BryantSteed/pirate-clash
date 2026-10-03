extends Node


func _ready() -> void:
	$StartButton.pressed.connect(self._on_press)
	$AudioStreamPlayer.play()


func _on_press() -> void:
	var explanationScene := preload("res://menus/explanation/explanation.tscn")
	var explanationInstance = explanationScene.instantiate()
	$AudioStreamPlayer.reparent(explanationInstance)
	get_tree().change_scene_to_node(explanationInstance)
