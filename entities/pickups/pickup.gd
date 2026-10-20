class_name Pickup
extends Area2D
## Something lying on the floor that the player walks over: a heart, an ammo
## box or a blank. Enemies drop them (see roll_drop and Enemy._die).
##
##     Pickup.spawn(room, Vector2(100, 40), Pickup.Kind.HEART)
##
## RULES (Gungeon style)
##   - It is only taken when it would help: a heart stays on the floor at full
##     health, ammo when every gun is full, a blank at the maximum. Come back
##     for it later.
##   - Close to the player it drifts toward them (the "magnet").
##
## ART: everything visible is under `Visual`, built by _build_visual() for
## now. Replace that node (sprite, animation) and nothing else changes.

signal collected(kind: int)

## Add new kinds at the END (8b adds coins).
enum Kind { HEART, AMMO, BLANK }

const SCENE: PackedScene = preload("res://entities/pickups/pickup.tscn")
const PLAYER_GROUP := "player"

@export var kind: Kind = Kind.HEART
## Hearts healed / blanks given.
@export var amount: int = 1
## Ammo boxes refill this fraction of every gun's MAX reserve.
@export_range(0.0, 1.0) var ammo_fraction: float = 0.4
## Within this distance a wanted pickup flies to the player.
@export var magnet_radius: float = 64.0
@export var magnet_speed: float = 240.0

## Drop chances per enemy kill (before the enemy's own multiplier).
const DROP_CHANCES := {Kind.HEART: 0.06, Kind.AMMO: 0.14, Kind.BLANK: 0.03}

var _bob_time: float = 0.0

@onready var visual: Node2D = $Visual


## Creates a pickup of `kind` at `world_position` under `parent`. The position
## is set before the node enters the tree and the add is deferred, so it is safe
## to call in the middle of a physics step (e.g. from an enemy's death).
static func spawn(parent: Node, world_position: Vector2, pickup_kind: int) -> Pickup:
	var pickup := SCENE.instantiate() as Pickup
	pickup.kind = pickup_kind as Kind
	pickup.position = parent.to_local(world_position) if parent is Node2D else world_position
	parent.add_child.call_deferred(pickup)
	return pickup


## Which kind (if any) an enemy kill drops. `luck` scales every chance.
## Returns -1 for "nothing". Pass your own rng to make it repeatable.
static func roll_drop(rng: RandomNumberGenerator, luck: float = 1.0) -> int:
	var roll := rng.randf()
	var total := 0.0
	for pickup_kind in DROP_CHANCES:
		total += DROP_CHANCES[pickup_kind] * luck
		if roll < total:
			return pickup_kind
	return -1


func _ready() -> void:
	collision_layer = 32   # layer 6 "pickup"
	collision_mask = 2     # sees the player
	_build_visual()
	_bob_time = randf() * TAU
	# A small pop-in so a drop doesn't just appear.
	visual.scale = Vector2.ZERO
	create_tween().tween_property(visual, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _physics_process(delta: float) -> void:
	_bob_time += delta * 4.0
	visual.position.y = sin(_bob_time) * 1.5   # gentle float, visual only

	var player := get_tree().get_first_node_in_group(PLAYER_GROUP) as Player
	if player == null or not can_collect(player):
		return
	var to_player := player.global_position - global_position
	if to_player.length() < magnet_radius:
		global_position += to_player.normalized() * magnet_speed * delta
	if overlaps_body(player):
		_collect(player)


## Would picking this up help the player right now?
func can_collect(player: Player) -> bool:
	if player.state == Player.State.DEAD:
		return false
	match kind:
		Kind.HEART:
			return player.health < player.max_health
		Kind.AMMO:
			return player.weapon_manager.weapons.any(func(w): return not w.data.infinite_ammo and w.reserve < w.data.max_reserve_ammo)
		Kind.BLANK:
			return player.blanks < player.max_blanks
	return false


func _collect(player: Player) -> void:
	var label := ""
	var color := Color.WHITE
	match kind:
		Kind.HEART:
			player.heal(amount)
			label = "+HP"
			color = Color(1.0, 0.45, 0.5)
		Kind.AMMO:
			for weapon in player.weapon_manager.weapons:
				if not weapon.data.infinite_ammo:
					weapon.add_ammo(ceili(weapon.data.max_reserve_ammo * ammo_fraction))
			label = "+AMMO"
			color = Color(1.0, 0.9, 0.4)
		Kind.BLANK:
			player.add_blanks(amount)
			label = "+BLANK"
			color = Color(0.6, 0.9, 1.0)
	FloatingText.spawn(get_parent(), global_position + Vector2(0.0, -10.0), label, color, 10)
	collected.emit(kind)
	set_physics_process(false)
	queue_free()


## PLACEHOLDER art, one shape per kind. Replace this (or the Visual node) with
## a sprite when the real art arrives.
func _build_visual() -> void:
	for child in visual.get_children():
		child.queue_free()
	var polygon := Polygon2D.new()
	match kind:
		Kind.HEART:
			polygon.color = Color(0.9, 0.2, 0.3)
			polygon.polygon = PackedVector2Array([Vector2(0, 7), Vector2(-8, -1), Vector2(-5, -6), Vector2(0, -3), Vector2(5, -6), Vector2(8, -1)])
		Kind.AMMO:
			polygon.color = Color(0.95, 0.8, 0.25)
			polygon.polygon = PackedVector2Array([Vector2(-7, -5), Vector2(7, -5), Vector2(7, 5), Vector2(-7, 5)])
		Kind.BLANK:
			polygon.color = Color(0.45, 0.85, 1.0)
			var points := PackedVector2Array()
			for i in 12:
				points.append(Vector2.from_angle(TAU * i / 12.0) * 6.0)
			polygon.polygon = points
	visual.add_child(polygon)
