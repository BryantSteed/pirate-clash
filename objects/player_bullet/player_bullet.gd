class_name PlayerBullet
extends Area2D

const SCENE_PATH := "res://objects/player_bullet/player_bullet.tscn"
const CloudScene := preload("res://objects/pirate_cloud/pirate_cloud.tscn")

@export var speed := 700.0
@export var lifetime := 3.0              # seconds before a missed bullet cleans itself up

var direction := Vector2.ZERO
var shooter: Node2D


# Factory: use this instead of instantiating the scene directly.
# load() rather than preload() because the scene references this script (a cycle).
static func create(from: Vector2, dir: Vector2, shooter_node: Node2D) -> PlayerBullet:
	var scene := load(SCENE_PATH) as PackedScene
	var bullet := scene.instantiate() as PlayerBullet
	bullet.global_position = from
	bullet.direction = dir.normalized()
	bullet.rotation = dir.angle()        # point the bullet the way it's flying
	bullet.shooter = shooter_node
	return bullet


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	get_tree().create_timer(lifetime).timeout.connect(queue_free)


func _physics_process(delta: float) -> void:
	position += direction * speed * delta


func _on_body_entered(body: Node2D) -> void:
	if body == shooter:
		return
	var pirate := body as Pirate
	if pirate:
		pirate.hit()
	else:
		var cloud = CloudScene.instantiate()
		cloud.global_position = self.global_position
		get_parent().add_child(cloud)
	queue_free()
