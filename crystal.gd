extends Area2D


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	self.body_entered.connect(self._on_entered)


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

func _on_entered(body: Node2D) -> void:
	if body is Player:
		body.add_crystal()
		self.queue_free()
