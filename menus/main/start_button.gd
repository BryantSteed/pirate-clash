extends Button

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	self.pressed.connect(self._on_press)


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

func _on_press() -> void:
	self.text = "You just pressed this button!"
	var explanationScene := preload("res://menus/explanation/explanation.tscn")
	get_tree().change_scene_to_packed(explanationScene)
