class_name Weapon
extends Node
## One gun IN THE PLAYER'S HANDS: a WeaponData (the stats) plus the changing
## state (bullets in the magazine, reserve ammo, cooldown, reload progress).
##
## Two guns with the same WeaponData still have their own ammo, because each
## has its own Weapon node. WeaponManager creates and owns these.
## This class never reads input: the manager tells it when to fire.

signal fired
signal reload_started
signal reload_finished
## Tried to fire with nothing loaded and nothing to reload.
signal dry_fired

const DEFAULT_BULLET: PackedScene = preload("res://entities/projectiles/bullet.tscn")
## Physics layers (see project.godot): bits are 1 = world, 4 = enemy.
const WORLD_MASK := 1
const PLAYER_BULLET_HIT_MASK := 1 | 4

var data: WeaponData
var magazine: int = 0
var reserve: int = 0
var reloading: bool = false

## The node that holds the gun (the Player). Used for position and physics.
var shooter: Node2D

var _cooldown_left: float = 0.0
var _reload_left: float = 0.0


func setup(weapon_data: WeaponData, owner_node: Node2D) -> void:
	data = weapon_data
	shooter = owner_node
	magazine = data.magazine_size
	reserve = data.starting_reserve_ammo
	name = data.display_name


func _physics_process(delta: float) -> void:
	_cooldown_left = maxf(0.0, _cooldown_left - delta)
	if reloading:
		_reload_left -= delta
		if _reload_left <= 0.0:
			_finish_reload()


# --- Queries (the HUD and manager read these) ---------------------------------

func can_fire() -> bool:
	return not reloading and _cooldown_left <= 0.0 and magazine > 0


## True when the gun has nothing left to shoot, even after reloading.
func is_out_of_ammo() -> bool:
	return magazine <= 0 and reserve <= 0 and not data.infinite_ammo


func can_reload() -> bool:
	if reloading or magazine >= data.magazine_size:
		return false
	return data.infinite_ammo or reserve > 0


## 0.0 (just started) to 1.0 (done). Only meaningful while reloading.
func reload_progress() -> float:
	if not reloading or data.reload_time <= 0.0:
		return 0.0
	return clampf(1.0 - _reload_left / data.reload_time, 0.0, 1.0)


func ammo_text() -> String:
	var reserve_text := "∞" if data.infinite_ammo else str(reserve)
	return "%d / %s" % [magazine, reserve_text]


# --- Actions --------------------------------------------------------------------

## Fires one shot if allowed. `aim` must be a unit vector. Returns true if fired.
func try_fire(muzzle_position: Vector2, aim: Vector2) -> bool:
	if magazine <= 0:
		# Empty magazine: reload automatically, or click dry if truly empty.
		if can_reload():
			start_reload()
		elif is_out_of_ammo():
			dry_fired.emit()
		return false
	if not can_fire():
		return false

	var origin := _safe_origin(muzzle_position)
	var count := maxi(1, data.projectiles_per_shot)
	for i in count:
		# Evenly spread the bullets across the cone, centred on the aim...
		var angle := 0.0
		if count > 1:
			angle = lerpf(-data.spread_degrees * 0.5, data.spread_degrees * 0.5, float(i) / float(count - 1))
		# ...then add a little randomness to each one.
		angle += randf_range(-data.inaccuracy_degrees, data.inaccuracy_degrees)
		_spawn_bullet(origin, aim.rotated(deg_to_rad(angle)))

	magazine -= 1
	_cooldown_left = 1.0 / maxf(data.fire_rate, 0.01)
	fired.emit()

	if magazine == 0 and can_reload():
		start_reload()  # Gungeon reloads on its own when the magazine runs dry.
	return true


func start_reload() -> void:
	if not can_reload():
		return
	reloading = true
	_reload_left = data.reload_time
	reload_started.emit()


## Called when the player swaps away: reload progress is lost.
func cancel_reload() -> void:
	reloading = false
	_reload_left = 0.0


func add_ammo(amount: int) -> void:
	reserve = mini(data.max_reserve_ammo, reserve + amount)


# --- Internals --------------------------------------------------------------------

func _finish_reload() -> void:
	reloading = false
	var needed := data.magazine_size - magazine
	if data.infinite_ammo:
		magazine += needed
	else:
		var taken := mini(needed, reserve)
		magazine += taken
		reserve -= taken
	reload_finished.emit()


## If the muzzle has poked through a wall (player pressed against it), spawn the
## bullet at the player's centre instead so it hits the wall straight away
## rather than appearing on the far side.
func _safe_origin(muzzle_position: Vector2) -> Vector2:
	var query := PhysicsRayQueryParameters2D.create(shooter.global_position, muzzle_position, WORLD_MASK)
	var hit := shooter.get_world_2d().direct_space_state.intersect_ray(query)
	return shooter.global_position if not hit.is_empty() else muzzle_position


func _spawn_bullet(origin: Vector2, direction: Vector2) -> void:
	var scene: PackedScene = data.bullet_scene if data.bullet_scene else DEFAULT_BULLET
	var bullet := scene.instantiate() as Bullet
	bullet.damage = data.damage
	bullet.speed = data.bullet_speed * (1.0 + randf_range(-data.speed_variance, data.speed_variance))
	bullet.lifetime = data.bullet_lifetime
	bullet.bounces = data.bounces
	bullet.pierce = data.pierce
	bullet.hit_mask = PLAYER_BULLET_HIT_MASK
	bullet.color = data.color
	bullet.direction = direction
	# Added next to the shooter, i.e. into the level (not under the player), so
	# bullets keep their own position when the player moves and disappear with
	# the level when it is freed.
	shooter.get_parent().add_child(bullet)
	bullet.global_position = origin  # set after add_child so it is in world space
