class_name Enemy
extends CharacterBody2D
## Base class for every shooting enemy. A new enemy type is NOT a new script:
## it is a scene inheriting enemy.tscn, with different numbers in the Inspector
## (health, speed, movement style) and a different EnemyAttack resource.
##
## SCENE LAYOUT (enemy.tscn)
##   Enemy (this script)       physics layer "enemy"
##   |- CollisionShape2D
##   `- Visual                 everything you see lives here (swap for sprites
##                             later). This script only changes Visual's scale
##                             and modulate (tint), which works on any node.
##
## STATE MACHINE (one state at a time, shown top to bottom in a normal life):
##   DORMANT    waiting for activate() (a room will do that when you enter it)
##   SPAWNING   fading in, can't be hurt yet, can't attack
##   IDLE       moving around; attacks when off cooldown and it can see you
##   WINDUP     warning flash before shooting, so the player can react
##   ATTACKING  firing volleys of bullets
##   DEAD       shrinking away
##
## The state machine uses plain timers (not `await`) so nothing can fire after
## the enemy is freed.
##
## KNOWN LIMIT: enemies steer straight at the player and slide along walls.
## Real pathfinding comes with the dungeon generator.

signal died(enemy: Enemy)

enum State { DORMANT, SPAWNING, IDLE, WINDUP, ATTACKING, DEAD }
enum Movement {
	STATIONARY,     ## never moves (turrets)
	APPROACH,       ## walks toward the player until preferred_distance
	KEEP_DISTANCE,  ## holds preferred_distance: backs off if close, strafes when in range
}

## Physics layer bits: 1 = world, 2 = player, 256 = cover (flipped tables).
## Enemy bullets hit all three.
const BULLET_HIT_MASK := 1 | 2 | 256
const WORLD_MASK := 1

@export_group("Stats")
@export var max_health: float = 20.0
## Seconds spent fading in, harmless and untouchable.
@export var spawn_delay: float = 0.5
## true: wakes up by itself. Rooms set this to false and call activate().
@export var auto_activate: bool = true

@export_group("Movement")
@export var movement: Movement = Movement.APPROACH
@export var move_speed: float = 55.0
@export var acceleration: float = 500.0
@export var preferred_distance: float = 170.0
## Dead zone around preferred_distance where a KEEP_DISTANCE enemy strafes.
@export var distance_tolerance: float = 25.0
## Speed multiplier during windup and attack (0 = stand still while shooting).
@export_range(0.0, 1.0) var moves_while_attacking: float = 0.0

@export_group("Attack")
@export var attack: EnemyAttack

@export_group("Feedback")
## Floating damage numbers. Handy while testing weapons; turn off for release.
@export var show_damage_numbers: bool = true

var state: State = State.DORMANT
var health: float = 0.0
var target: Player

var _spawn_left: float = 0.0
var _windup_left: float = 0.0
var _cooldown_left: float = 0.0
var _shot_index: int = 0
var _shot_timer: float = 0.0
var _random_offset: float = 0.0
var _strafe_sign: float = 1.0
var _strafe_left: float = 0.0
var _hit_flash_left: float = 0.0
var _can_see_target: bool = false
var _base_scale: Vector2 = Vector2.ONE

@onready var visual: Node2D = $Visual


func _ready() -> void:
	add_to_group("enemies")  # lets blanks and other effects find every enemy
	health = max_health
	_base_scale = visual.scale
	if auto_activate:
		activate()


## Wakes a dormant enemy. Does nothing if it is already awake.
func activate() -> void:
	if state != State.DORMANT:
		return
	state = State.SPAWNING
	_spawn_left = spawn_delay


func _physics_process(delta: float) -> void:
	_hit_flash_left = maxf(0.0, _hit_flash_left - delta)

	match state:
		State.DORMANT, State.DEAD:
			velocity = Vector2.ZERO
		State.SPAWNING:
			_spawn_left -= delta
			if _spawn_left <= 0.0:
				_finish_spawning()
		State.IDLE:
			_refresh_target()
			_move(delta, 1.0)
			_cooldown_left = maxf(0.0, _cooldown_left - delta)
			if _wants_to_attack():
				_begin_windup()
		State.WINDUP:
			_refresh_target()
			_move(delta, moves_while_attacking)
			_windup_left -= delta
			if _windup_left <= 0.0:
				_begin_attack()
		State.ATTACKING:
			_refresh_target()
			_move(delta, moves_while_attacking)
			_process_attack(delta)

	move_and_slide()
	_update_visuals()


# --- Public API ---------------------------------------------------------------

## Called by bullets. Returns true when the hit landed (see Bullet).
func take_damage(amount: float) -> bool:
	if state == State.DORMANT or state == State.SPAWNING or state == State.DEAD:
		return false  # untouchable: bullets pass through
	health -= amount
	_hit_flash_left = 0.08
	if show_damage_numbers:
		FloatingText.spawn(get_parent(), global_position + Vector2(0.0, -24.0), ("%.1f" % amount).trim_suffix(".0"))
	if health <= 0.0:
		_die()
	return true


func is_alive() -> bool:
	return state != State.DEAD


## Shoves the enemy (blanks, explosions...). It is a one-off speed boost that
## the normal movement then slows back down, so it feels like a push.
## Turrets don't move, and enemies that are not fighting yet are ignored.
func apply_knockback(direction: Vector2, strength: float) -> void:
	if movement == Movement.STATIONARY:
		return
	if state == State.DORMANT or state == State.SPAWNING or state == State.DEAD:
		return
	velocity = direction.normalized() * strength


# --- Spawning and dying ---------------------------------------------------------

func _finish_spawning() -> void:
	state = State.IDLE
	# First attack comes a little after spawning, and differs per enemy.
	_cooldown_left = randf_range(0.4, 1.2)
	_strafe_left = 0.0


func _die() -> void:
	state = State.DEAD
	velocity = Vector2.ZERO
	collision_layer = 0  # bullets and the player no longer touch it
	collision_mask = 0
	died.emit(self)
	var tween := create_tween()
	tween.tween_property(visual, "scale", Vector2.ZERO, 0.15)
	tween.tween_callback(queue_free)


# --- Target ---------------------------------------------------------------------

func _refresh_target() -> void:
	if not is_instance_valid(target):
		target = get_tree().get_first_node_in_group("player") as Player
	_can_see_target = _has_line_of_sight()


func _target_alive() -> bool:
	return is_instance_valid(target) and target.state != Player.State.DEAD


## True when no wall is between us and the player.
func _has_line_of_sight() -> bool:
	if not _target_alive():
		return false
	var query := PhysicsRayQueryParameters2D.create(global_position, target.global_position, WORLD_MASK)
	return get_world_2d().direct_space_state.intersect_ray(query).is_empty()


func _distance_to_target() -> float:
	return global_position.distance_to(target.global_position) if _target_alive() else INF


# --- Movement ---------------------------------------------------------------------

func _move(delta: float, speed_factor: float) -> void:
	var desired := _desired_velocity() * speed_factor
	velocity = velocity.move_toward(desired, acceleration * delta)


func _desired_velocity() -> Vector2:
	if movement == Movement.STATIONARY or not _target_alive():
		return Vector2.ZERO

	var to_target := target.global_position - global_position
	var distance := to_target.length()
	var direction := to_target.normalized()

	match movement:
		Movement.APPROACH:
			# Keep walking if too far OR if a wall blocks the view.
			if distance > preferred_distance or not _can_see_target:
				return direction * move_speed
		Movement.KEEP_DISTANCE:
			if distance > preferred_distance + distance_tolerance or not _can_see_target:
				return direction * move_speed
			if distance < preferred_distance - distance_tolerance:
				return -direction * move_speed
			# In the sweet spot: circle around the player, changing direction now and then.
			_strafe_left -= get_physics_process_delta_time()
			if _strafe_left <= 0.0:
				_strafe_sign = -_strafe_sign if randf() < 0.5 else _strafe_sign
				_strafe_left = randf_range(1.0, 2.5)
			return direction.orthogonal() * _strafe_sign * move_speed * 0.6
	return Vector2.ZERO


# --- Attacking ----------------------------------------------------------------------

func _wants_to_attack() -> bool:
	return (
		attack != null
		and _cooldown_left <= 0.0
		and _can_see_target
		and _distance_to_target() <= attack.attack_range
	)


func _begin_windup() -> void:
	state = State.WINDUP
	_windup_left = attack.windup_time


func _begin_attack() -> void:
	state = State.ATTACKING
	_shot_index = 0
	_shot_timer = 0.0  # first volley immediately
	_random_offset = randf() * TAU


func _process_attack(delta: float) -> void:
	_shot_timer -= delta
	# `while`, not `if`: a very short interval may need several volleys in one frame.
	while _shot_timer <= 0.0 and _shot_index < attack.shots:
		_fire_volley()
		_shot_index += 1
		_shot_timer += maxf(attack.shot_interval, 0.001)
	if _shot_index >= attack.shots:
		_end_attack()


func _fire_volley() -> void:
	var aim_angle := 0.0
	if _target_alive():
		aim_angle = (target.global_position - global_position).angle()
	var scene := attack.get_bullet_scene()
	for angle in attack.get_angles(_shot_index, aim_angle, _random_offset):
		var direction := Vector2.from_angle(angle)
		Bullet.spawn(
			scene, self, global_position + direction * 12.0, direction,
			attack.bullet_speed, attack.bullet_damage, attack.bullet_lifetime,
			BULLET_HIT_MASK, attack.bullet_color,
		)


func _end_attack() -> void:
	state = State.IDLE
	_cooldown_left = maxf(0.0, attack.cooldown + randf_range(-attack.cooldown_jitter, attack.cooldown_jitter))


# --- Visuals --------------------------------------------------------------------------

## Only touches Visual's scale and modulate, so it works with any art.
func _update_visuals() -> void:
	var tint := Color.WHITE
	var scale_factor := 1.0

	match state:
		State.DORMANT:
			tint.a = 0.25
		State.SPAWNING:
			var progress := 1.0 - clampf(_spawn_left / maxf(spawn_delay, 0.001), 0.0, 1.0)
			tint.a = 0.25 + 0.5 * progress
		State.WINDUP:
			# Pulse toward bright yellow and swell: "I'm about to shoot".
			var progress := 1.0 - clampf(_windup_left / maxf(attack.windup_time, 0.001), 0.0, 1.0)
			var pulse := 0.5 + 0.5 * sin(progress * TAU * 3.0)
			tint = Color.WHITE.lerp(Color(2.0, 1.8, 0.6), 0.4 + 0.6 * pulse)
			scale_factor = 1.0 + 0.2 * progress

	if _hit_flash_left > 0.0:
		tint = Color(3.0, 3.0, 3.0)

	if state != State.DEAD:  # the death tween owns the scale
		visual.scale = _base_scale * scale_factor
	visual.modulate = tint
