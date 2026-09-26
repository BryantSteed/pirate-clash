@tool
extends StaticBody2D

# A solid rectangle, centered on the node's origin. @tool so edits show live in the editor.

@export var size := Vector2(200, 20):
	set(value):
		size = value
		if is_node_ready():
			_apply()

@export var color := Color(1, 0.22, 1):
	set(value):
		color = value
		if is_node_ready():
			_apply()


func _ready() -> void:
	_apply()


func _apply() -> void:
	# The shape is "local to scene" in platform.tscn, so each instance resizes its own copy.
	($CollisionShape2D.shape as RectangleShape2D).size = size
	$ColorRect.size = size
	$ColorRect.position = -size / 2
	$ColorRect.color = color
