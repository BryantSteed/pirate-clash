class_name LevelBounds
extends ReferenceRect

# The playable area of a level. The camera reads it for its limits (see player_camera.gd),
# and at runtime it builds invisible walls along the enabled edges so nothing leaves the world.
# Put one in each level, in the "level_bounds" group.

@export var wall_left := true
@export var wall_right := true
@export var wall_top := true      # off by default: jumping above the top edge is harmless
@export var wall_bottom := true    # turn off once pits have a death zone instead


func _ready() -> void:
	var walls := StaticBody2D.new()
	walls.name = "Walls"
	# WorldBoundaryShape2D is an infinite line: points where point·normal < distance are solid.
	# Coordinates are local to this rect, whose top-left is (0, 0).
	if wall_left:
		_add_wall(walls, Vector2.RIGHT, 0.0)
	if wall_right:
		_add_wall(walls, Vector2.LEFT, -size.x)
	if wall_top:
		_add_wall(walls, Vector2.DOWN, 0.0)
	if wall_bottom:
		_add_wall(walls, Vector2.UP, -size.y)
	add_child(walls)


func _add_wall(body: StaticBody2D, normal: Vector2, distance: float) -> void:
	var boundary := WorldBoundaryShape2D.new()
	boundary.normal = normal         # points into the playable area
	boundary.distance = distance
	var shape := CollisionShape2D.new()
	shape.shape = boundary
	body.add_child(shape)
