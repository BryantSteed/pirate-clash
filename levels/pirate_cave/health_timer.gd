extends Timer

@export var hit_penalty: float = 5.0

signal time_penalized(amount: float)

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	get_tree().get_first_node_in_group("player").was_hit.connect(self._on_hit)


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

func _on_hit() -> void:
	var new_time := self.time_left - hit_penalty
	# Not proud of this quick and dirty fix. The better way is to signal the end of game directly
	new_time = maxf(new_time, 0.0001)
	self.start(new_time)
	time_penalized.emit(hit_penalty)
