class_name Player
extends CharacterBody2D

@export var speed := 350.0
@export var acceleration := 3000.0       # how fast you reach full speed (px/s²)
@export var friction := 4000.0           # how fast you stop when no key is held (px/s²)
@export var jump_velocity := -550.0      # negative = up
@export var fall_gravity_scale := 1.6    # fall faster than you rise, for a snappier arc
@export var jump_cut := 0.5              # releasing jump early keeps this fraction of upward speed
@export var coyote_time := 0.1           # can still jump this long after walking off a ledge
@export var jump_buffer := 0.1           # a jump pressed this long before landing still counts

var _coyote_timer := 0.0
var _jump_buffer_timer := 0.0

var crystal_count := 0

func add_crystal() -> void:
	# Called by crystal when player enter it
	crystal_count += 1

func _physics_process(delta: float) -> void:
	_apply_gravity(delta)
	_handle_jump(delta)
	_handle_horizontal(delta)
	move_and_slide()


func _apply_gravity(delta: float) -> void:
	if is_on_floor():
		return
	var gravity := get_gravity()
	if velocity.y > 0:
		gravity *= fall_gravity_scale
	velocity += gravity * delta


func _handle_jump(delta: float) -> void:
	if is_on_floor():
		_coyote_timer = coyote_time
	else:
		_coyote_timer -= delta

	if Input.is_action_just_pressed("up"):
		_jump_buffer_timer = jump_buffer
	else:
		_jump_buffer_timer -= delta

	if _jump_buffer_timer > 0 and _coyote_timer > 0:
		velocity.y = jump_velocity
		_jump_buffer_timer = 0
		_coyote_timer = 0

	# Variable jump height: letting go early cuts the jump short.
	if Input.is_action_just_released("up") and velocity.y < 0:
		velocity.y *= jump_cut


func _handle_horizontal(delta: float) -> void:
	var direction := Input.get_axis("left", "right")
	var rate := acceleration if direction != 0 else friction
	velocity.x = move_toward(velocity.x, direction * speed, rate * delta)
