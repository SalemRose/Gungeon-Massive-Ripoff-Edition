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
const PLAYER_BULLET_HIT_MASK := 1 | 4

var data: WeaponData
var magazine: int = 0
var reserve: int = 0
var reloading: bool = false

## The node that holds the gun (the Player). Used for position and physics.
var shooter: Node2D

var _cooldown_left: float = 0.0
var _reload_left: float = 0.0
## BURST guns: shots still to come in the current burst, and the wait for the next.
var _burst_left: int = 0
var _burst_timer: float = 0.0
## CHARGE guns: 0.0 (nothing) to 1.0 (full). The HUD reads it.
var charge: float = 0.0
var _charging: bool = false
## BEAM guns: true while the laser is on.
var beaming: bool = false
var _beam_tick_left: float = 0.0
var _beam_ammo_owed: float = 0.0
var _beam_fx: BeamEffect
## Charge of the shot being fired (0 for non-charge guns).
var _shot_charge: float = 0.0
## ORBIT guns: the orbs currently circling (oldest first) and their shared angle.
var _orbs: Array[OrbitOrb] = []
var _orbit_angle: float = 0.0


func setup(weapon_data: WeaponData, owner_node: Node2D) -> void:
	data = weapon_data
	shooter = owner_node
	magazine = data.magazine_size
	reserve = data.starting_reserve_ammo
	name = data.display_name


func _physics_process(delta: float) -> void:
	_cooldown_left = maxf(0.0, _cooldown_left - delta)
	_process_burst(delta)
	_process_orbs(delta)
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

	_shoot(muzzle_position, aim)
	_cooldown_left = 1.0 / maxf(data.fire_rate, 0.01)
	if data.fire_mode == WeaponData.FireMode.BURST and data.burst_count > 1:
		# The rest of the burst follows by itself (see _process_burst). The next
		# click is only possible after the whole burst plus the usual cooldown.
		_burst_left = data.burst_count - 1
		_burst_timer = data.burst_interval
		_cooldown_left += data.burst_interval * float(data.burst_count - 1)
	return true


## CHARGE guns: call every frame the fire button is held.
func hold_charge(delta: float) -> void:
	if reloading or magazine <= 0:
		if magazine <= 0 and can_reload():
			start_reload()
		return
	_charging = true
	charge = minf(1.0, charge + delta / maxf(data.charge_time, 0.01))


## CHARGE guns: call when the button is let go. Fires if charged enough.
func release_charge(muzzle_position: Vector2, aim: Vector2) -> bool:
	var amount := charge
	var was_charging := _charging
	_charging = false
	charge = 0.0
	if not was_charging or amount < data.min_charge or not can_fire():
		return false
	_shot_charge = amount
	_shoot(muzzle_position, aim)
	_shot_charge = 0.0
	_cooldown_left = 1.0 / maxf(data.fire_rate, 0.01)
	return true


## BEAM guns: call every physics frame the fire button is held. Casts the laser
## along `aim`, draws it, burns ammo, and damages what it touches every tick.
func hold_beam(delta: float, muzzle_position: Vector2, aim: Vector2) -> void:
	if reloading or magazine <= 0:
		stop_beam()
		if magazine <= 0 and can_reload():
			start_reload()
		return
	beaming = true
	var origin := Bullet.safe_spawn_position(shooter, muzzle_position)
	var trace := _trace_beam(origin, aim)
	if _beam_fx == null or not is_instance_valid(_beam_fx):
		_beam_fx = BeamEffect.new()
		shooter.get_parent().add_child(_beam_fx)
	_beam_fx.show_beam(origin, trace.end, data.color)
	# Ammo: a fraction per frame, whole bullets come off the magazine.
	_beam_ammo_owed += data.beam_ammo_per_second * delta
	while _beam_ammo_owed >= 1.0 and magazine > 0:
		_beam_ammo_owed -= 1.0
		magazine -= 1
	# Damage on a timer, not every frame (the numbers would be unreadable).
	_beam_tick_left -= delta
	if _beam_tick_left <= 0.0:
		_beam_tick_left += maxf(data.beam_tick, 0.02)
		for target in trace.targets:
			if is_instance_valid(target):
				target.take_damage(data.damage * data.beam_tick)
		fired.emit()
	if magazine <= 0:
		stop_beam()
		if can_reload():
			start_reload()


func stop_beam() -> void:
	beaming = false
	_beam_tick_left = 0.0
	if _beam_fx != null and is_instance_valid(_beam_fx):
		_beam_fx.hide_beam()


## Drops anything the gun is in the middle of (charge, beam, burst).
func cancel_hold() -> void:
	_charging = false
	charge = 0.0
	_burst_left = 0
	stop_beam()


func start_reload() -> void:
	if not can_reload():
		return
	cancel_hold()
	reloading = true
	_reload_left = data.reload_time
	reload_started.emit()


## Called when the player swaps away: reload progress is lost.
func cancel_reload() -> void:
	reloading = false
	_reload_left = 0.0
	cancel_hold()   # swapping away also drops a charge, a beam or the rest of a burst


func add_ammo(amount: int) -> void:
	reserve = mini(data.max_reserve_ammo, reserve + amount)


# --- Internals --------------------------------------------------------------------

## One shot: the bullets of a single trigger pull, one ammo, then the signal.
func _shoot(muzzle_position: Vector2, aim: Vector2) -> void:
	if data.fire_mode == WeaponData.FireMode.ORBIT:
		_add_orb()
	else:
		var origin := Bullet.safe_spawn_position(shooter, muzzle_position)
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
	fired.emit()

	if magazine == 0 and can_reload():
		start_reload()  # Gungeon reloads on its own when the magazine runs dry.


## Follows the beam from `origin` along `aim`: where it ends, and every enemy
## (or other target) it passes through. It stops at the first wall, and after
## `pierce` extra targets.
func _trace_beam(origin: Vector2, aim: Vector2) -> Dictionary:
	var space := shooter.get_world_2d().direct_space_state
	var end := origin + aim * data.beam_range
	var targets: Array = []
	var ignored: Array[RID] = []
	var passes := data.pierce
	while true:
		var query := PhysicsRayQueryParameters2D.create(origin, origin + aim * data.beam_range, PLAYER_BULLET_HIT_MASK, ignored)
		var hit := space.intersect_ray(query)
		if hit.is_empty():
			break
		end = hit.position
		var collider := hit.collider as Object
		if collider != null and collider.has_method("take_damage"):
			targets.append(collider)
			if passes <= 0:
				break
			passes -= 1
			ignored.append(hit.rid)
		else:
			break   # a wall
	return {"end": end, "targets": targets}


## ORBIT: adds one orb; if the limit is reached the oldest one goes.
func _add_orb() -> void:
	_prune_orbs()
	while _orbs.size() >= data.orbit_max_orbs:
		_orbs.pop_front().expire()
	var orb := OrbitOrb.new()
	orb.damage = data.damage
	orb.lifetime = data.orbit_duration
	orb.color = data.color
	orb.position = shooter.global_position   # sensible start; _process_orbs places it
	shooter.get_parent().add_child(orb)
	_orbs.append(orb)


## Keeps every orb on its place of the circle around the player, evenly spread.
func _process_orbs(delta: float) -> void:
	_prune_orbs()
	if _orbs.is_empty():
		return
	_orbit_angle = wrapf(_orbit_angle + deg_to_rad(data.orbit_speed_degrees) * delta, 0.0, TAU)
	for i in _orbs.size():
		var angle := _orbit_angle + TAU * float(i) / float(_orbs.size())
		_orbs[i].global_position = shooter.global_position + Vector2.from_angle(angle) * data.orbit_radius


## Forgets orbs that have run out.
func _prune_orbs() -> void:
	_orbs = _orbs.filter(func(o): return is_instance_valid(o) and not o.is_queued_for_deletion()) as Array[OrbitOrb]


## The follow-up shots of a burst. They aim wherever the player aims NOW, and
## stop if the player rolls, dies, swaps gun, or the magazine runs out.
func _process_burst(delta: float) -> void:
	if _burst_left <= 0:
		return
	var player := shooter as Player
	if player == null or player.state != Player.State.NORMAL or magazine <= 0 or reloading:
		_burst_left = 0
		return
	_burst_timer -= delta
	if _burst_timer <= 0.0:
		_burst_left -= 1
		_burst_timer += data.burst_interval
		_shoot(player.muzzle.global_position, player.aim_direction)

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


func _spawn_bullet(origin: Vector2, direction: Vector2) -> void:
	var scene: PackedScene = data.bullet_scene if data.bullet_scene else DEFAULT_BULLET
	var bullet := scene.instantiate() as Bullet
	bullet.damage = data.damage
	bullet.speed = data.bullet_speed * (1.0 + randf_range(-data.speed_variance, data.speed_variance))
	bullet.lifetime = data.bullet_lifetime
	bullet.bounces = data.bounces
	bullet.pierce = data.pierce
	bullet.homing_turn_rate = data.homing_turn_rate
	bullet.homing_range = data.homing_range
	bullet.boomerang_out_time = data.boomerang_out_time
	bullet.owner_node = shooter
	bullet.hit_mask = PLAYER_BULLET_HIT_MASK
	bullet.color = data.color
	bullet.direction = direction
	if data.fire_mode == WeaponData.FireMode.CHARGE:
		# 1x damage with no charge, charge_damage_multiplier x at full.
		bullet.damage = data.damage * lerpf(1.0, data.charge_damage_multiplier, _shot_charge)
		if _shot_charge >= 0.99:
			bullet.pierce += data.charge_full_pierce
	# Added next to the shooter, i.e. into the level (not under the player), so
	# bullets keep their own position when the player moves and disappear with
	# the level when it is freed.
	shooter.get_parent().add_child(bullet)
	bullet.global_position = origin  # set after add_child so it is in world space
	if data.fire_mode == WeaponData.FireMode.CHARGE:
		bullet.visual.scale = Vector2.ONE * (1.0 + _shot_charge * 1.5)   # a charged shot looks bigger
