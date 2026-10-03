extends Node2D


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	$CloudSprite.animation_finished.connect(self._on_finished)
	$CloudSprite.play("poof")

func _on_finished() -> void:
	queue_free()

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
