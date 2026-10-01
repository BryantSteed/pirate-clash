extends Node

const PauseMenu := preload("res://menus/pause_menu/pause_menu.tscn")

# This is the count down timer
@onready var healthTimer := $HealthTimer

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	healthTimer.start()
	healthTimer.timeout.connect(self._on_time_up)

func _on_time_up() -> void:
	get_tree().change_scene_to_file("res://menus/game_over/GameOver.tscn")

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		# Overlay the menu instead of changing scenes, so the level is kept and resumes as it was.
		get_viewport().set_input_as_handled()   # don't let the new menu see this same press and close itself
		add_child(PauseMenu.instantiate())
		get_tree().paused = true
