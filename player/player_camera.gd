extends Camera2D

# Reads its limits from the level's LevelBounds (the node in the "level_bounds" group).
# No bounds = no limits.


func _ready() -> void:
	var bounds := get_tree().get_first_node_in_group("level_bounds") as LevelBounds
	if bounds == null:
		return
	var rect := bounds.get_global_rect()
	limit_left = int(rect.position.x)
	limit_top = int(rect.position.y)
	limit_right = int(rect.end.x)
	limit_bottom = int(rect.end.y)
