extends Node


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	var random_draw := randi_range(0, 1)
	if random_draw == 0:
		$option1.play(true)
	else:
		$option2.play(true)
