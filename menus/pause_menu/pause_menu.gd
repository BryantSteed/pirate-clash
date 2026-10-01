extends CanvasLayer

# Shown on top of the running level, which is frozen by get_tree().paused.
# The root's Process Mode is "Always" so this menu still works while everything else is paused.

const OptionsScene := preload("res://menus/options/options.tscn")


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	$QuitButton.pressed.connect(self._on_quit_pressed)
	$OptionsButton.pressed.connect(self._on_options_pressed)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()
		_resume()

func _resume() -> void:
	get_tree().paused = false
	queue_free()

func _on_options_pressed() -> void:
	var options := OptionsScene.instantiate()
	# Hide while options is open: hidden buttons can't be clicked through the options screen.
	visible = false
	options.tree_exited.connect(func(): visible = true)
	add_child(options)

func _on_quit_pressed() -> void:
	get_tree().quit()
