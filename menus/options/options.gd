extends CanvasLayer

# Opened on top of the pause menu; closing it (Back or the pause key) reveals the pause menu again.

# Master bus = every sound in the game (all players use it by default).
@onready var master_bus := AudioServer.get_bus_index("Master")


func _ready() -> void:
	# Linear 0..1 rather than decibels, so the slider feels even across its range.
	$HSlider.min_value = 0.0
	$HSlider.max_value = 1.0
	$HSlider.step = 0.01
	# Start at the current volume; it lives on the AudioServer, so it carries over between scenes.
	$HSlider.value = AudioServer.get_bus_volume_linear(master_bus)
	$HSlider.value_changed.connect(self._on_volume_changed)
	$BackButton.pressed.connect(self.queue_free)

func _unhandled_input(event: InputEvent) -> void:
	# Handled here first (children get input before their parent), so the pause key
	# backs out of options instead of also closing the pause menu.
	if event.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()
		queue_free()

func _on_volume_changed(value: float) -> void:
	AudioServer.set_bus_volume_linear(master_bus, value)
