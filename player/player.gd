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
@export var fire_cooldown := 0.25        # minimum seconds between shots

var _coyote_timer := 0.0
var _jump_buffer_timer := 0.0
var _fire_cooldown_timer := 0.0

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D

signal was_hit

var crystal_count := 0

func add_crystal() -> void:
	# Called by crystal when player enter it
	crystal_count += 1

func hit() -> void:
	# Called by a pirate bullet on contact. What a hit means (damage, death) is still TBD.
	print("Player hit!")
	was_hit.emit()

func _unhandled_input(event: InputEvent) -> void:
	# _unhandled_input (not _input) so clicks on UI buttons don't also fire.
	if event.is_action_pressed("shoot") and _fire_cooldown_timer <= 0:
		_shoot()


func _physics_process(delta: float) -> void:
	_fire_cooldown_timer -= delta
	_apply_gravity(delta)
	_handle_jump(delta)
	_handle_horizontal(delta)
	move_and_slide()
	_update_animation()


func _update_animation() -> void:
	# Face the way we're moving; keep the last facing when standing still.
	if velocity.x != 0:
		sprite.flip_h = velocity.x < 0
	# play() on the animation that's already playing is a no-op, so calling it every tick is fine.
	# Once there's a "run" animation: sprite.play("run" if absf(velocity.x) > 10 else "idle")
	if absf(velocity.x) > 10:
		sprite.play("run")
	else:
		sprite.play("idle")


func _shoot() -> void:
	_fire_cooldown_timer = fire_cooldown
	var dir := global_position.direction_to(get_global_mouse_position())
	# Add to the level, not the player, so bullets don't follow the player around.
	get_parent().add_child(PlayerBullet.create(global_position, dir, self))


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
