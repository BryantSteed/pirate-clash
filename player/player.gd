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
@export var recoil_strength := 500.0     # kick applied opposite the shot direction (px/s)
@export var recoil_strength_second_shot := 300.0
@export var max_recoil_speed := 900.0    # recoil can't push total speed above this (px/s)
@export var air_acceleration := 1500.0   # steering in the air (vs acceleration on the ground)
@export var air_friction := 600.0        # coasting in the air (vs friction on the ground)
@export var overspeed_decel := 900.0     # how fast momentum above `speed` (e.g. recoil) bleeds off
@export var max_air_shots := 2          # shots allowed while airborne; ground shots are free
@export var hit_stun_time := 0.5         # after a hit: frozen in place (no gravity/input) and can't be hit again
@export var air_hand_raise := 30.0       # how far the gun hand moves up while the "jump" pose shows (px)
@export var muzzle_offset := Vector2(11, 3)  # barrel tip, in GunSprite's local space (from the gun art)

var _coyote_timer := 0.0
var _jump_buffer_timer := 0.0
var _fire_cooldown_timer := 0.0
var _air_shots := 0          # shots fired while airborne since the last landing
var _stun_timer := 0.0       # > 0 while frozen and invulnerable after a hit (the "hit" animation shows)

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var gun_pivot: Node2D = $GunPivot
@onready var _hand_position: Vector2 = gun_pivot.position   # right-hand anchor, as placed in the editor
@onready var gun_sprite: AnimatedSprite2D = $GunPivot/GunSprite

signal was_hit

signal crystal_collected

signal crystal_count_changed(count: int)

var crystal_count := 0:
	set(value):
		crystal_count = value
		crystal_count_changed.emit(crystal_count)   # the HUD listens for this

func add_crystal() -> void:
	# Called by crystal when player enter it
	crystal_count += 1
	$CollectCrystalSound.play()
	crystal_collected.emit()     # the health timer listens for this to add time

func hit() -> void:
	# Called by a pirate bullet on contact. What a hit means (damage, death) is still TBD.
	if _stun_timer > 0:
		return               # invulnerable while stunned
	_stun_timer = hit_stun_time
	velocity = Vector2.ZERO
	# Stretch/squeeze "hit" so it plays through exactly once over the stun.
	sprite.speed_scale = _animation_length("hit") / maxf(hit_stun_time, 0.01)
	sprite.stop()            # restart from frame 0
	sprite.play("hit")
	$HurtSound.play()
	was_hit.emit()


func _animation_length(anim: StringName) -> float:
	# Seconds the animation takes at speed_scale 1 (frames can have individual durations).
	var frames := sprite.sprite_frames
	var total := 0.0
	for i in frames.get_frame_count(anim):
		total += frames.get_frame_duration(anim, i)
	return total / frames.get_animation_speed(anim)

func _unhandled_input(event: InputEvent) -> void:
	# _unhandled_input (not _input) so clicks on UI buttons don't also fire.
	var shoot_action_pressed := event.is_action_pressed("shoot")
	var fire_cooldown_finished := _fire_cooldown_timer <= 0
	var air_shot_limit_not_exceeded := is_on_floor() or self._air_shots < self.max_air_shots
	var not_stunned := _stun_timer <= 0

	if shoot_action_pressed and fire_cooldown_finished and air_shot_limit_not_exceeded and not_stunned:
		_shoot()


func _physics_process(delta: float) -> void:
	_fire_cooldown_timer -= delta
	if _stun_timer > 0:
		# Frozen: no gravity, no input, no movement until the stun runs out.
		_stun_timer -= delta
		velocity = Vector2.ZERO
		_update_animation()
		return
	_apply_gravity(delta)
	_handle_jump(delta)
	_handle_horizontal(delta)
	move_and_slide()
	_update_animation()


func _process(_delta: float) -> void:
	# Aiming is purely visual, so it runs every rendered frame for smooth tracking.
	gun_pivot.visible = _stun_timer <= 0     # the gun disappears while the hit stun lasts
	_aim_gun()


func _aim_gun() -> void:
	var mouse := get_global_mouse_position()
	# Which side is decided from the player's center, not the hand, so the swap point
	# doesn't move as the hand moves (that would make it flicker between hands).
	var aiming_left := mouse.x < global_position.x

	# In the air the arm is drawn higher, so raise the hand to match the "jump" pose.
	var hand := _hand_position
	if sprite.animation == &"jump":
		hand.y -= air_hand_raise

	# Swap hands: mirror the anchor across the player's center, and mirror the gun with it.
	gun_pivot.position = Vector2(-hand.x if aiming_left else hand.x, hand.y)
	gun_pivot.scale.x = -1 if aiming_left else 1

	# Rotate about the hand so the barrel (the gun's +x) points at the mouse.
	# Mirrored, the barrel points along -x, i.e. rotation + PI, hence the + PI.
	var to_mouse := mouse - gun_pivot.global_position
	gun_pivot.rotation = to_mouse.angle() + (PI if aiming_left else 0.0)


func _update_animation() -> void:
	# Face the way we're moving; keep the last facing when standing still.
	if velocity.x != 0:
		sprite.flip_h = velocity.x < 0
	if _stun_timer > 0:
		return               # keep showing "hit" for the whole stun
	sprite.speed_scale = 1.0 # undo the stun's stretch
	# play() on the animation that's already playing is a no-op, so calling it every tick is fine.
	if not is_on_floor():
		sprite.play("jump")
	elif absf(velocity.x) > 10:
		sprite.play("run")
	else:
		sprite.play("idle")


func _ready() -> void:
	# "shoot" doesn't loop, so it stops on its last frame; stop() rewinds to frame 0 (the resting gun).
	gun_sprite.animation_finished.connect(gun_sprite.stop)
	# One-way platforms let you land as soon as you're over their line, even with the line
	# halfway up your body. While a platform is inside the body, ignore it, so you only land
	# on platforms that are actually under your feet.
	$PassThroughSensor.body_entered.connect(_pass_through_started)
	$PassThroughSensor.body_exited.connect(_pass_through_ended)
	
func _pass_through_started(node: Node2D) -> void:
	add_collision_exception_with(node)
	
func _pass_through_ended(node: Node2D) -> void:
	remove_collision_exception_with(node)


func _shoot() -> void:
	_fire_cooldown_timer = fire_cooldown
	gun_sprite.stop()        # restart from frame 0 even if the last shot's animation is still playing
	gun_sprite.play("shoot")
	$ShootSound.play()
	# Spawn at the barrel tip. to_global() applies the whole chain (sprite position, pivot
	# rotation, hand-swap mirror, player position), so this follows the gun however it's aimed.
	var muzzle := gun_sprite.to_global(muzzle_offset)
	var mouse := get_global_mouse_position()
	var dir := muzzle.direction_to(mouse)
	# If the cursor is on top of or behind the muzzle, muzzle->mouse would point backwards;
	# fall back to the way the barrel is facing.
	var barrel_dir := (muzzle - gun_sprite.to_global(muzzle_offset - Vector2(10, 0))).normalized()
	if muzzle.distance_to(mouse) < 20.0 or dir.dot(barrel_dir) < 0:
		dir = barrel_dir
	# Add to the level, not the player, so bullets don't follow the player around.
	get_parent().add_child(PlayerBullet.create(muzzle, dir, self))
	# Ground shots and the first shot in the air get full recoil; later air shots get the weaker one.
	var recoil_modifier: float
	if is_on_floor() or self._air_shots == 0:
		recoil_modifier = self.recoil_strength
	else:
		recoil_modifier = self.recoil_strength_second_shot
	if not is_on_floor():
		self._air_shots += 1
	var recoil := -dir * recoil_modifier
	# Cap the result so rapid shots don't stack into huge speeds. If we were already
	# moving faster than the cap (e.g. a long fall), recoil can redirect us but not speed us up.
	var cap := maxf(max_recoil_speed, velocity.length())
	if recoil.y < 0:
		# Shooting downward: guarantee at least this much upward speed instead of adding to it,
		# so the kick replaces a fall but doesn't stack on top of a jump.
		velocity.y = minf(velocity.y, recoil.y)
		velocity.x += recoil.x
	else:
		velocity += recoil
	velocity = velocity.limit_length(cap)


func _apply_gravity(delta: float) -> void:
	if is_on_floor():
		# is_on_floor() is still true for one tick after a jump or launch, so only a real
		# landing (not moving up) refills air shots.
		if velocity.y >= 0:
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
		$JumpSound.play()
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
