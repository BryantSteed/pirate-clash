extends CharacterBody2D

@export var shoot_interval := 2.0        # seconds between shots

# Groups are joined on entering the tree, which happens for every node before any
# _ready()/@onready runs, so the player is findable regardless of sibling order.
@onready var target := get_tree().get_first_node_in_group("player") as Player


func _ready() -> void:
	var shoot_timer := Timer.new()
	shoot_timer.wait_time = shoot_interval
	shoot_timer.autostart = true
	shoot_timer.timeout.connect(_shoot)
	add_child(shoot_timer)


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity += get_gravity() * delta
	move_and_slide()


func _shoot() -> void:
	if not is_instance_valid(target):
		return
	# TODO: line-of-sight check goes here
	var dir := global_position.direction_to(target.global_position)
	# Add to the level, not the pirate, so bullets don't move or die with the pirate.
	get_parent().add_child(PirateBullet.create(global_position, dir, self))
