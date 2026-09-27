extends CanvasLayer

# Screen-space overlay. Only displays things; it listens for changes instead of polling.

@onready var crystal_label: Label = $CrystalLabel
@onready var timerLabel: Label = $TimerLabel
@onready var healthTimer: Timer = get_tree().get_first_node_in_group("health_timer")


func _ready() -> void:
	var player := get_tree().get_first_node_in_group("player") as Player
	if player == null:
		return
	player.crystal_count_changed.connect(_on_crystal_count_changed)
	_on_crystal_count_changed(player.crystal_count)   # show the starting value
	
func _process(delta: float) -> void:
	timerLabel.text = "Time: %d" % healthTimer.time_left


func _on_crystal_count_changed(count: int) -> void:
	crystal_label.text = "Crystals: %d" % count
