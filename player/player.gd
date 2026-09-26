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
@export var recoil_strength := 450.0     # kick applied opposite the shot direction (px/s)
@export var recoil_strength_second_shot := 150.0
@export var max_recoil_speed := 900.0    # recoil can't push total speed above this (px/s)
@export var air_acceleration := 1500.0   # steering in the air (vs acceleration on the ground)
@export var air_friction := 600.0        # coasting in the air (vs friction on the ground)
@export var overspeed_decel := 900.0     # how fast momentum above `speed` (e.g. recoil) bleeds off
@export var max_air_shots := 2

var _coyote_timer := 0.0
var _jump_buffer_timer := 0.0
var _fire_cooldown_timer := 0.0
var _air_shots := 0

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
	var shoot_action_pressed := event.is_action_pressed("shoot")
	var fire_cooldown_finished := _fire_cooldown_timer <= 0
	var air_shot_limit_not_exceeded := self._air_shots < self.max_air_shots
	
	if shoot_action_pressed and fire_cooldown_finished and air_shot_limit_not_exceeded:
		_shoot()
		self._air_shots += 1


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
	if dir.y > 0:
		velocity.y = minf(velocity.y, 0.0)   # shooting downward cancels the fall, so the boost is consistent
	# Cap the result so rapid shots don't stack into huge speeds. If we were already
	# moving faster than the cap (e.g. a long fall), recoil can redirect us but not speed us up.
	var cap := maxf(max_recoil_speed, velocity.length())
	var recoil_modifier
	if self._air_shots == 0:
		recoil_modifier = self.recoil_strength
	else:
		recoil_modifier = self.recoil_strength_second_shot
	velocity = (velocity - dir * recoil_strength).limit_length(cap)


func _apply_gravity(delta: float) -> void:
	if is_on_floor():
		self._air_shots = 0
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
	var on_floor := is_on_floor()
	var rate: float
	if absf(velocity.x) > speed and signf(direction) != -signf(velocity.x):
		rate = overspeed_decel                             # carrying extra momentum: let it glide
	elif direction != 0:
		rate = acceleration if on_floor else air_acceleration
	else:
		rate = friction if on_floor else air_friction
	velocity.x = move_toward(velocity.x, direction * speed, rate * delta)
