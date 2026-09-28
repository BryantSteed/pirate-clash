class_name Pirate
extends CharacterBody2D

@export var shoot_interval := 2.0        # seconds between shots
@export var max_health := 1              # hits to kill (1 = one-shot, as before)
@export var hurt_time := 0.4             # seconds the "hurt" pose shows; no shooting meanwhile
@export var muzzle_offset := Vector2(11, 3)  # barrel tip, in the gun sprite's local space (same gun art as the player)

var _health := 3
var _hurt_timer := 0.0                   # > 0 while showing "hurt"

# Groups are joined on entering the tree, which happens for every node before any
# _ready()/@onready runs, so the player is findable regardless of sibling order.
@onready var target := get_tree().get_first_node_in_group("player") as Player
@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var gun_pivot: Node2D = $GunPivot
@onready var _hand_position: Vector2 = gun_pivot.position   # right-hand anchor, as placed in the editor
@onready var gun_sprite: AnimatedSprite2D = $GunPivot/AnimatedSprite2D   # rename to GunSprite in the scene, then update this path

func _ready() -> void:
	_health = max_health
	sprite.play("idle")
	# "shoot" doesn't loop, so it stops on its last frame; stop() rewinds to frame 0 (the resting gun).
	gun_sprite.animation_finished.connect(gun_sprite.stop)
	var shoot_timer := Timer.new()
	shoot_timer.wait_time = shoot_interval
	shoot_timer.autostart = true
	shoot_timer.timeout.connect(_shoot)
	add_child(shoot_timer)


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity += get_gravity() * delta
	move_and_slide()

	if _hurt_timer > 0:
		_hurt_timer -= delta
		if _hurt_timer <= 0:
			if _health <= 0:
				queue_free()             # the hurt pose was its death; now it's gone
			else:
				sprite.play("idle")


func _process(_delta: float) -> void:
	# Facing is purely visual, so it runs every rendered frame.
	if is_instance_valid(target):
		_face_target()


func _face_target() -> void:
	# Same rig as the player's gun, but aimed at the player instead of the mouse.
	var target_pos := target.global_position
	var target_left := target_pos.x < global_position.x

	# Body faces the player (assumes the art faces right by default).
	sprite.flip_h = target_left

	# Swap hands: mirror the anchor across the pirate's center, and mirror the gun with it.
	gun_pivot.position = Vector2(-_hand_position.x if target_left else _hand_position.x, _hand_position.y)
	gun_pivot.scale.x = -1 if target_left else 1

	# Rotate about the hand so the barrel points at the player.
	# Mirrored, the barrel points along -x, i.e. rotation + PI, hence the + PI.
	var to_target := target_pos - gun_pivot.global_position
	gun_pivot.rotation = to_target.angle() + (PI if target_left else 0.0)


func hit() -> void:
	# Called by a player bullet on contact.
	if _health <= 0:
		return                           # already dying
	_health -= 1
	_hurt_timer = hurt_time
	sprite.play("hurt")
	if _health <= 0:
		# Dying: stop being hittable or solid, but keep the mask so it still stands on the floor.
		# Deferred because we're inside a physics callback (the bullet's body_entered).
		set_deferred("collision_layer", 0)


func _shoot() -> void:
	if not is_instance_valid(target) or _hurt_timer > 0 or _health <= 0:
		return
	# TODO: line-of-sight check goes here
	gun_sprite.stop()        # restart from frame 0 in case the last shot's animation is still playing
	gun_sprite.play("shoot")
	# Spawn at the barrel tip. to_global() applies the whole chain (gun position, pivot
	# rotation, hand-swap mirror, pirate position), so this follows the gun however it's aimed.
	var muzzle := gun_sprite.to_global(muzzle_offset)
	var dir := muzzle.direction_to(target.global_position)
	# If the player is on top of or behind the muzzle, muzzle->player would point backwards;
	# fall back to the way the barrel is facing.
	var barrel_dir := (muzzle - gun_sprite.to_global(muzzle_offset - Vector2(10, 0))).normalized()
	if muzzle.distance_to(target.global_position) < 20.0 or dir.dot(barrel_dir) < 0:
		dir = barrel_dir
	# Add to the level, not the pirate, so bullets don't move or die with the pirate.
	get_parent().add_child(PirateBullet.create(muzzle, dir, self))
