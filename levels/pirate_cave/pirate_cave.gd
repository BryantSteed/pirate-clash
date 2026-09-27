extends Node

# This is the count down timer
@onready var healthTimer := $HealthTimer

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	healthTimer.start()
	healthTimer.timeout.connect(self._on_time_up)

func _on_time_up() -> void:
	get_tree().change_scene_to_file("res://menus/game_over/GameOver.tscn")
