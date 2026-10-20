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

## Add new kinds at the END.
enum Kind { HEART, AMMO, BLANK, COIN }

const SCENE: PackedScene = preload("res://entities/pickups/pickup.tscn")
const PLAYER_GROUP := "player"

@export var kind: Kind = Kind.HEART
## Hearts healed / blanks given / coins worth.
@export var amount: int = 1
## Ammo boxes refill this fraction of every gun's MAX reserve.
@export_range(0.0, 1.0) var ammo_fraction: float = 0.4
## Within this distance a wanted pickup flies to the player.
@export var magnet_radius: float = 64.0
@export var magnet_speed: float = 240.0

## Drop chances per enemy kill (before the enemy's own multiplier).
const DROP_CHANCES := {Kind.HEART: 0.06, Kind.AMMO: 0.14, Kind.BLANK: 0.03}

## Coins dropped per kill: index = how many (0..3), value = chance (sums to 1).
const COIN_DROP_ODDS := [0.40, 0.40, 0.15, 0.05]

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


## How many coins an enemy kill drops (0 to 3). `luck` shifts odds upward.
static func roll_coins(rng: RandomNumberGenerator, luck: float = 1.0) -> int:
	if luck <= 0.0:
		return 0
	var roll := rng.randf()
	var count := 0
	var total := 0.0
	for i in COIN_DROP_ODDS.size():
		total += COIN_DROP_ODDS[i]
		if roll < total:
			count = i
			break
	# More luck: a chance for one extra coin.
	if luck > 1.0 and rng.randf() < luck - 1.0:
		count += 1
	return count


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
	return is_useful(player, kind)


## Would a `pickup_kind` help `player` right now? (Shops ask this too, so you
## are never charged for a heart at full health.)
static func is_useful(player: Player, pickup_kind: int) -> bool:
	if player.state == Player.State.DEAD:
		return false
	match pickup_kind:
		Kind.HEART:
			return player.health < player.max_health
		Kind.AMMO:
			return player.weapon_manager.weapons.any(func(w): return not w.data.infinite_ammo and w.reserve < w.data.max_reserve_ammo)
		Kind.BLANK:
			return player.blanks < player.max_blanks
		Kind.COIN:
			return true
	return false


## Gives the player what `pickup_kind` is worth. Returns the floating-text
## label and its color (for the caller to show). Used by pickups and shops.
static func apply_effect(player: Player, pickup_kind: int, count: int = 1, fraction: float = 0.4) -> Dictionary:
	match pickup_kind:
		Kind.HEART:
			player.heal(count)
			return {"label": "+HP", "color": Color(1.0, 0.45, 0.5)}
		Kind.AMMO:
			for weapon in player.weapon_manager.weapons:
				if not weapon.data.infinite_ammo:
					weapon.add_ammo(ceili(weapon.data.max_reserve_ammo * fraction))
			return {"label": "+AMMO", "color": Color(1.0, 0.9, 0.4)}
		Kind.BLANK:
			player.add_blanks(count)
			return {"label": "+BLANK", "color": Color(0.6, 0.9, 1.0)}
		Kind.COIN:
			player.add_coins(count)
			return {"label": "+%d" % count, "color": Color(1.0, 0.85, 0.2)}
	return {"label": "", "color": Color.WHITE}


func _collect(player: Player) -> void:
	var result := apply_effect(player, kind, amount, ammo_fraction)
	FloatingText.spawn(get_parent(), global_position + Vector2(0.0, -10.0), result.label, result.color, 10)
	collected.emit(kind)
	set_physics_process(false)
	queue_free()


## PLACEHOLDER art, one shape per kind. Replace this (or the Visual node) with
## a sprite when the real art arrives.
func _build_visual() -> void:
	for child in visual.get_children():
		child.queue_free()
	visual.add_child(make_icon(kind))


## The placeholder shape for a kind (shops draw the same icons).
static func make_icon(pickup_kind: int) -> Polygon2D:
	var polygon := Polygon2D.new()
	match pickup_kind:
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
		Kind.COIN:
			polygon.color = Color(1.0, 0.82, 0.2)
			var coin_points := PackedVector2Array()
			for i in 10:
				coin_points.append(Vector2.from_angle(TAU * i / 10.0) * 4.5)
			polygon.polygon = coin_points
	return polygon
