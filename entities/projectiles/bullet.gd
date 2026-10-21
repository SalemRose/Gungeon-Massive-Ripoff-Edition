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
## HOMING (player bullets): turn speed toward the nearest enemy in degrees per
## second, and how far away it can see one. 0 = flies straight.
@export var homing_turn_rate: float = 0.0
@export var homing_range: float = 240.0
## BOOMERANG: flies out for this many seconds (0 = off), then comes back to
## `owner_node`. See _update_boomerang().
@export var boomerang_out_time: float = 0.0
## Who a boomerang returns to (set by the Weapon).
var owner_node: Node2D

## Physics layer bit for walls and other solid level geometry.
const WORLD_MASK := 1
## Physics layer bit of the player.
const PLAYER_MASK := 2
## Physics layer bit of enemies.
const ENEMY_MASK := 4

var direction: Vector2 = Vector2.RIGHT

var _age: float = 0.0
var _boomerang_returning: bool = false
var _boomerang_time: float = 0.0
## Close enough to the owner to be caught (pixels).
const BOOMERANG_CATCH_DISTANCE := 14.0
## Typed as Node2D (not Enemy) on purpose: Enemy already refers to Bullet, and two
## scripts naming each other's class make Godot fail to load them.
var _homing_target: Node2D
var _retarget_left: float = 0.0
## How often a homing bullet looks for a (new) target.
const HOMING_RETARGET_TIME := 0.12
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
	homing_turn_rate = 0.0
	boomerang_out_time = 0.0
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
	if boomerang_out_time > 0.0:
		if not _update_boomerang(delta):
			return   # caught

	if homing_turn_rate > 0.0:
		_steer_homing(delta)

	var from := global_position
	var to := from + direction * speed * delta
	var query := PhysicsRayQueryParameters2D.create(from, to, hit_mask, _ignored)
	var hit := get_world_2d().direct_space_state.intersect_ray(query)

	if hit.is_empty():
		global_position = to
	else:
		_handle_hit(hit)


## BOOMERANG: out for boomerang_out_time, then it flies back to the owner and
## is caught. Spins while it flies. Returns false if it was caught (and freed).
func _update_boomerang(delta: float) -> bool:
	_boomerang_time += delta
	visual.rotation += delta * 18.0   # spin
	if not _boomerang_returning and _boomerang_time >= boomerang_out_time:
		_start_boomerang_return()
	if _boomerang_returning:
		if not is_instance_valid(owner_node):
			queue_free()
			return false
		var to_owner := owner_node.global_position - global_position
		if to_owner.length() <= BOOMERANG_CATCH_DISTANCE:
			queue_free()
			return false
		direction = to_owner.normalized()
	return true


## Turn around: it can hurt every enemy again on the way back. The way back
## ignores walls (it flies straight to you), so it never gets stuck on a corner.
func _start_boomerang_return() -> void:
	_boomerang_returning = true
	_ignored.clear()
	hit_mask &= ~WORLD_MASK
	speed *= 1.15


## Turns the bullet toward the nearest reachable enemy (never faster than
## homing_turn_rate, so a fast turn-around is impossible: it curves).
func _steer_homing(delta: float) -> void:
	_retarget_left -= delta
	if not _can_home_on(_homing_target) or _retarget_left <= 0.0:
		_retarget_left = HOMING_RETARGET_TIME
		_homing_target = _find_homing_target()
	if _homing_target == null:
		return
	var wanted := (_homing_target.global_position - global_position).angle()
	var step := deg_to_rad(homing_turn_rate) * delta
	var turn := clampf(angle_difference(direction.angle(), wanted), -step, step)
	direction = direction.rotated(turn)
	rotation = direction.angle()


## The closest living enemy within range with no wall in between, or null.
func _find_homing_target() -> Node2D:
	var best: Node2D = null
	var best_distance := homing_range
	var space := get_world_2d().direct_space_state
	for node in get_tree().get_nodes_in_group("enemies"):
		var enemy := node as Node2D
		if not _can_home_on(enemy):
			continue
		var distance := global_position.distance_to(enemy.global_position)
		if distance >= best_distance:
			continue
		var query := PhysicsRayQueryParameters2D.create(global_position, enemy.global_position, WORLD_MASK)
		if space.intersect_ray(query).is_empty():
			best = enemy
			best_distance = distance
	return best


## Only enemies that can actually be hurt right now are worth chasing.
func _can_home_on(enemy: Node2D) -> bool:
	return is_instance_valid(enemy) and enemy.has_method("can_be_targeted") and enemy.can_be_targeted()


func _handle_hit(hit: Dictionary) -> void:
	global_position = hit.position
	var collider := hit.collider as Object

	if collider and collider.has_method("take_damage"):
		_ignored.append(hit.rid)
		var landed: bool = collider.take_damage(damage)
		if not landed:
			return  # e.g. the player is mid-roll: the bullet passes through
		if boomerang_out_time > 0.0:
			return  # a boomerang goes straight through enemies
		if pierce > 0:
			pierce -= 1
			return
		queue_free()
		return

	# Anything else is a wall. A boomerang that hits one on the way out turns
	# back early.
	if boomerang_out_time > 0.0 and not _boomerang_returning:
		_start_boomerang_return()
		global_position += hit.normal * 0.5
		return
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
