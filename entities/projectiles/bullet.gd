class_name Bullet
extends Node2D
## A single bullet. Used for player AND enemy bullets: who it can hit is decided
## by `hit_mask` (a physics-layer bitmask), set by whoever spawns it.
##
## HOW IT MOVES AND HITS
## Instead of an Area2D that waits for overlaps, each physics frame we cast a
## ray along the distance the bullet is about to travel. That has two benefits:
##   1. Fast bullets can never skip through thin walls.
##   2. The ray tells us the wall's surface normal, which is exactly what
##      bouncing needs.
##
## HOW IT DAMAGES THINGS
## Anything with a `take_damage(amount: float) -> bool` method can be shot:
## enemies, the player, breakable props. Return true if the hit landed, or
## false to let the bullet fly on (the player's dodge roll does this).
##
## ART: everything visible is under the `Visual` node. Replace its polygon with
## a sprite later; this script only reads/changes Visual's colour.

@export var speed: float = 500.0
@export var damage: float = 1.0
@export var lifetime: float = 1.2
@export var bounces: int = 0
## Extra targets the bullet can pass through before it stops.
@export var pierce: int = 0
## Physics layers this bullet collides with. Default: world (1) + enemies (4).
@export_flags_2d_physics var hit_mask: int = 5
@export var color: Color = Color(1.0, 0.9, 0.4)

var direction: Vector2 = Vector2.RIGHT

var _age: float = 0.0
## Things already hit/passed through: the ray ignores them from then on, so a
## bullet can't hit the same enemy twice or get stuck inside a rolling player.
var _ignored: Array[RID] = []

@onready var visual: Polygon2D = $Visual


func _ready() -> void:
	visual.color = color
	rotation = direction.angle()


func _physics_process(delta: float) -> void:
	_age += delta
	if _age >= lifetime:
		queue_free()
		return

	var from := global_position
	var to := from + direction * speed * delta
	var query := PhysicsRayQueryParameters2D.create(from, to, hit_mask, _ignored)
	var hit := get_world_2d().direct_space_state.intersect_ray(query)

	if hit.is_empty():
		global_position = to
	else:
		_handle_hit(hit)


func _handle_hit(hit: Dictionary) -> void:
	global_position = hit.position
	var collider := hit.collider as Object

	if collider and collider.has_method("take_damage"):
		_ignored.append(hit.rid)
		var landed: bool = collider.take_damage(damage)
		if not landed:
			return  # e.g. the player is mid-roll: the bullet passes through
		if pierce > 0:
			pierce -= 1
			return
		queue_free()
		return

	# Anything else is a wall.
	if bounces > 0:
		bounces -= 1
		direction = direction.bounce(hit.normal)
		rotation = direction.angle()
		global_position += hit.normal * 0.5  # nudge off the wall so we don't re-hit it
	else:
		queue_free()
