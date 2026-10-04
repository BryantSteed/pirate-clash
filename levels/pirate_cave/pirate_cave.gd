extends Node

# Intended to be mutated after istantiation
var rank_achieved: String

const PauseMenu := preload("res://menus/pause_menu/pause_menu.tscn")
const GameWonMenu := preload("res://menus/game_won/GameWon.tscn")
const MouseRetical := preload("res://art/mouse retical.png")

# This is the count down timer
@onready var healthTimer := $HealthTimer

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	healthTimer.start()
	healthTimer.timeout.connect(self._on_time_up)
	$EndPortal.portal_traveled.connect(self._on_portal_entered)
	$CRTLite.preset = CRTLite.Preset.LIVING_ROOM_TV
	$CRTLite.set_crt("curvature", 0.02)
	$CRTLite.set_crt("scanlines", 0.4)
	$CRTLite.set_crt("corner_radius", 0.0)
	Input.set_custom_mouse_cursor(MouseRetical)

func _on_portal_entered() -> void:
	print("we did this")
	var MenuScene = GameWonMenu.instantiate()
	MenuScene.crystal_count = $Player.crystal_count
	MenuScene.time_left = $HealthTimer.time_left
	MenuScene.went_through_portal = true
	get_tree().change_scene_to_node(MenuScene)

func _on_time_up() -> void:
	var gameWonScene = GameWonMenu.instantiate()
	gameWonScene.crystal_count = $Player.crystal_count
	gameWonScene.time_left = 0.0
	gameWonScene.went_through_portal = false
	get_tree().change_scene_to_node(gameWonScene)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		# Overlay the menu instead of changing scenes, so the level is kept and resumes as it was.
		get_viewport().set_input_as_handled()   # don't let the new menu see this same press and close itself
		add_child(PauseMenu.instantiate())
		get_tree().paused = true
