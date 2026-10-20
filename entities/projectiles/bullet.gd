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
## a sprite later; this script only tints Visual (via `modulate`), which works
## on any kind of node. Keep the art white/neutral if you want the tint to show.

@export var speed: float = 500.0
@export var damage: float = 1.0
@export var lifetime: float = 1.2
@export var bounces: int = 0
## Extra targets the bullet can pass through before it stops.
@export var pierce: int = 0
## Physics layers this bullet collides with. Default: world (1) + enemies (4).
@export_flags_2d_physics var hit_mask: int = 5
@export var color: Color = Color(1.0, 0.9, 0.4)

## Physics layer bit for walls and other solid level geometry.
const WORLD_MASK := 1
## Physics layer bit of the player.
const PLAYER_MASK := 2
## Physics layer bit of enemies.
const ENEMY_MASK := 4

var direction: Vector2 = Vector2.RIGHT

var _age: float = 0.0
## Things already hit/passed through: the ray ignores them from then on, so a
## bullet can't hit the same enemy twice or get stuck inside a rolling player.
var _ignored: Array[RID] = []

@onready var visual: Node2D = $Visual


func _ready() -> void:
	add_to_group("bullets")  # lets blanks and other effects find every bullet
	visual.modulate = color
	rotation = direction.angle()


## True if this bullet can hurt the player (an enemy bullet).
func is_hostile() -> bool:
	return (hit_mask & PLAYER_MASK) != 0


## Turns an enemy bullet into the player's: it flies off in `new_direction`,
## now hurts enemies (and walls) instead of the player, and lives a fresh
## lifetime. Used by the melee swing. Safe to call on any bullet.
func deflect(new_direction: Vector2, new_damage: float, speed_multiplier: float, new_color: Color) -> void:
	direction = new_direction.normalized()
	rotation = direction.angle()
	hit_mask = WORLD_MASK | ENEMY_MASK
	damage = new_damage
	speed *= speed_multiplier
	bounces = 0
	pierce = 0
	_age = 0.0
	_ignored.clear()
	color = new_color
	visual.modulate = new_color
	# A little pop so the player sees it happen.
	visual.scale = Vector2(2.0, 2.0)
	create_tween().tween_property(visual, "scale", Vector2.ONE, 0.12)


## Removes the bullet with a quick pop instead of vanishing. It stops moving and
## stops hurting immediately; only the little animation is left.
func destroy() -> void:
	if is_queued_for_deletion() or not is_physics_processing():
		return
	set_physics_process(false)
	remove_from_group("bullets")
	var tween := create_tween().set_parallel(true)
	tween.tween_property(visual, "scale", Vector2(2.2, 2.2), 0.12)
	tween.tween_property(visual, "modulate:a", 0.0, 0.12)
	tween.chain().tween_callback(queue_free)


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


## One-call bullet creation, used by enemies (the player's Weapon builds its
## bullets itself because it also applies spread and speed variance).
## The bullet is added next to `shooter` (into the level, not under the shooter),
## so it keeps its own position when the shooter moves and disappears with the
## level when that is freed. The start position goes through
## safe_spawn_position(), so a shooter pressed against a wall can't leak
## bullets through it.
static func spawn(
	scene: PackedScene,
	shooter: Node2D,
	muzzle_position: Vector2,
	direction: Vector2,
	speed: float,
	damage: float,
	lifetime: float,
	hit_mask: int,
	color: Color,
	bounces: int = 0,
	pierce: int = 0,
) -> Bullet:
	var bullet := scene.instantiate() as Bullet
	bullet.direction = direction
	bullet.speed = speed
	bullet.damage = damage
	bullet.lifetime = lifetime
	bullet.hit_mask = hit_mask
	bullet.color = color
	bullet.bounces = bounces
	bullet.pierce = pierce

	var origin := safe_spawn_position(shooter, muzzle_position)
	shooter.get_parent().add_child(bullet)
	bullet.global_position = origin  # set after add_child so it is in world space
	return bullet


## Where a bullet fired by `shooter` should appear. Normally `wanted` (the
## muzzle), but if a wall lies between the shooter and the muzzle (shooter
## pressed against a wall) we spawn at the shooter's centre instead, so the
## bullet hits the wall straight away instead of appearing on the far side.
## Shared by the player's weapons and by enemy patterns.
static func safe_spawn_position(shooter: Node2D, wanted: Vector2) -> Vector2:
	var query := PhysicsRayQueryParameters2D.create(shooter.global_position, wanted, WORLD_MASK)
	var hit := shooter.get_world_2d().direct_space_state.intersect_ray(query)
	return shooter.global_position if not hit.is_empty() else wanted
