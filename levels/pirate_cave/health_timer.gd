extends Timer

@export var hit_penalty: float = 5.0
@export var crystal_time_bonus: float = 3.0   # seconds each collected crystal adds; time left is the final score

signal time_penalized(amount: float)
signal time_bonus_added(amount: float)

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	var player := get_tree().get_first_node_in_group("player")
	player.was_hit.connect(self._on_hit)
	player.crystal_collected.connect(self._on_crystal_collected)


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

func _on_hit() -> void:
	var new_time := self.time_left - hit_penalty
	# Not proud of this quick and dirty fix. The better way is to signal the end of game directly
	new_time = maxf(new_time, 0.0001)
	self.start(new_time)
	time_penalized.emit(hit_penalty)

func _on_crystal_collected() -> void:
	self.start(self.time_left + crystal_time_bonus)
	time_bonus_added.emit(crystal_time_bonus)
