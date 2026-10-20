class_name Player
extends CharacterBody2D
## Top-down player: movement, aiming (mouse OR gamepad), dodge roll, health.
##
## SCENE LAYOUT (player.tscn)
##   Player (this script)
##   |- CollisionShape2D   physics body, never changes with the art
##   |- Visual             EVERYTHING you see of the player body lives here.
##   |                     To add final art: delete the placeholder polygons
##   |                     inside it and drop in an AnimatedSprite2D.
##   |                     This script only touches Visual's rotation, scale
##   |                     and modulate, so it works with any art.
##   |- AimPivot           rotates to face the aim direction
##   |   |- GunPlaceholder  stand-in for the equipped weapon sprite
##   |   `- Muzzle          where bullets spawn
##   |       `- Flash       brief muzzle flash shown when a shot is fired
##   |- WeaponManager      shooting, ammo, reloading, weapon swapping
##   `- Camera2D           follows the player, leans toward the aim point

signal health_changed(current: int, maximum: int)
signal rolled(direction: Vector2)
signal blanks_changed(current: int, maximum: int)
signal died

enum State { NORMAL, ROLLING, DEAD }

@export_group("Movement")
@export var move_speed: float = 170.0
## How fast we reach full speed (px/s^2). Higher = snappier.
@export var acceleration: float = 1600.0
## How fast we stop when no key is held (px/s^2).
@export var friction: float = 2000.0

@export_group("Dodge Roll")
@export var roll_speed: float = 400.0
@export var roll_duration: float = 0.40
## The roll starts with this much invincibility (seconds), then you are
## vulnerable again while still finishing the animation, like Gungeon.
@export var roll_iframes: float = 0.28
@export var roll_cooldown: float = 0.12
## A dodge pressed up to this long BEFORE it becomes possible still fires.
## Makes chained rolls feel responsive instead of "eaten".
@export var roll_buffer_time: float = 0.12

@export_group("Blank")
@export var starting_blanks: int = 2
@export var max_blanks: int = 5
## Bullets inside this distance are destroyed (about one screen).
@export var blank_radius: float = 420.0
## Enemy push speed at the player's feet (weaker farther away).
@export var blank_knockback: float = 320.0
## Invincibility right after a blank, so it can save you from a point-blank hit.
@export var blank_iframes: float = 0.4
## Stops a double-tap from burning two blanks.
@export var blank_cooldown: float = 0.35

@export_group("Interaction")
## How close something must be to use it with the Interact button.
@export var interact_range: float = 44.0

@export_group("Aiming")
## 0 = camera stays on the player, 1 = camera sits on the cursor.
@export_range(0.0, 1.0) var camera_lean: float = 0.25
## Maximum camera offset from the player, in pixels.
@export var camera_max_offset: float = 90.0
@export var camera_follow_speed: float = 8.0
## How fast camera shake dies down (px/s).
@export var shake_decay: float = 60.0

@export_group("Health")
## Measured in half-hearts: 6 = three hearts.
@export var max_health: int = 6
## Invincibility after getting hit (seconds).
@export var hurt_iframes: float = 0.7

var state: State = State.NORMAL
var health: int
## Unit vector the player is aiming along. Weapons read this next step.
var aim_direction: Vector2 = Vector2.RIGHT
## True while the last input came from a gamepad (switches how we aim).
var using_gamepad: bool = false

var _roll_direction: Vector2 = Vector2.RIGHT
var _roll_time: float = 0.0
var _roll_cooldown_left: float = 0.0
var _roll_buffer_left: float = 0.0
var _hurt_iframes_left: float = 0.0
var blanks: int
var _blank_iframes_left: float = 0.0
var _blank_cooldown_left: float = 0.0
var _camera_lean: Vector2 = Vector2.ZERO
var _shake: float = 0.0
var _flash_left: float = 0.0

@onready var visual: Node2D = $Visual
@onready var aim_pivot: Node2D = $AimPivot
@onready var muzzle: Marker2D = $AimPivot/Muzzle
@onready var camera: Camera2D = $Camera2D
@onready var weapon_manager: WeaponManager = $WeaponManager


func _ready() -> void:
	add_to_group("player")  # lets enemies find us: get_tree().get_first_node_in_group("player")
	health = max_health
	health_changed.emit(health, max_health)
	blanks = mini(starting_blanks, max_blanks)
	blanks_changed.emit(blanks, max_blanks)


## _input sees every raw event. We only use it to detect WHICH device the
## player is using right now (mouse+keyboard vs gamepad).
func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion or event is InputEventMouseButton:
		using_gamepad = false
	elif event is InputEventJoypadButton:
		using_gamepad = true
	elif event is InputEventJoypadMotion:
		# Ignore stick drift: only switch when the stick is really pushed.
		if absf((event as InputEventJoypadMotion).axis_value) > 0.4:
			using_gamepad = true


## Physics runs at a fixed rate (60 Hz by default): movement code goes here.
func _physics_process(delta: float) -> void:
	_tick_timers(delta)
	_update_aim()

	match state:
		State.NORMAL:
			_process_normal(delta)
		State.ROLLING:
			_process_rolling(delta)
		State.DEAD:
			velocity = velocity.move_toward(Vector2.ZERO, friction * delta)

	move_and_slide()
	_update_camera(delta)
	_update_visuals()


# --- Per-frame helpers --------------------------------------------------------

func _tick_timers(delta: float) -> void:
	_roll_cooldown_left = maxf(0.0, _roll_cooldown_left - delta)
	_roll_buffer_left = maxf(0.0, _roll_buffer_left - delta)
	_hurt_iframes_left = maxf(0.0, _hurt_iframes_left - delta)
	_blank_iframes_left = maxf(0.0, _blank_iframes_left - delta)
	_blank_cooldown_left = maxf(0.0, _blank_cooldown_left - delta)

	if Input.is_action_just_pressed("dodge"):
		_roll_buffer_left = roll_buffer_time
	if Input.is_action_just_pressed("blank"):
		use_blank()
	if Input.is_action_just_pressed("interact") and state == State.NORMAL:
		try_interact()


func _update_aim() -> void:
	if using_gamepad:
		# get_vector applies the stick deadzone for us.
		var stick := Input.get_vector("aim_left", "aim_right", "aim_up", "aim_down")
		if stick != Vector2.ZERO:
			aim_direction = stick.normalized()
		# Stick released: keep the last direction instead of snapping back.
	else:
		var to_mouse := get_global_mouse_position() - global_position
		if to_mouse.length() > 4.0:  # avoid jitter with the cursor on top of us
			aim_direction = to_mouse.normalized()

	aim_pivot.rotation = aim_direction.angle()


func _process_normal(delta: float) -> void:
	var input := Input.get_vector("move_left", "move_right", "move_up", "move_down")

	if input != Vector2.ZERO:
		velocity = velocity.move_toward(input * move_speed, acceleration * delta)
	else:
		velocity = velocity.move_toward(Vector2.ZERO, friction * delta)

	if _roll_buffer_left > 0.0 and _roll_cooldown_left <= 0.0:
		_start_roll(input)


func _start_roll(move_input: Vector2) -> void:
	# Roll where we are moving; if standing still, roll toward the aim.
	_roll_direction = move_input.normalized() if move_input != Vector2.ZERO else aim_direction
	_roll_time = 0.0
	_roll_buffer_left = 0.0
	state = State.ROLLING
	rolled.emit(_roll_direction)


func _process_rolling(delta: float) -> void:
	_roll_time += delta
	var t := clampf(_roll_time / roll_duration, 0.0, 1.0)

	# Fast at the start, slowing toward the end: reads as a roll, not a slide.
	velocity = _roll_direction * lerpf(roll_speed, roll_speed * 0.45, t)

	if _roll_time >= roll_duration:
		state = State.NORMAL
		_roll_cooldown_left = roll_cooldown
		# Hand control back without a sudden speed jump.
		velocity = velocity.limit_length(move_speed)


func _update_camera(delta: float) -> void:
	# Lean the camera toward where we are aiming (Gungeon style).
	var target := Vector2.ZERO
	if using_gamepad:
		target = aim_direction * camera_max_offset * 0.5
	else:
		target = ((get_global_mouse_position() - global_position) * camera_lean).limit_length(camera_max_offset)
	_camera_lean = _camera_lean.lerp(target, clampf(camera_follow_speed * delta, 0.0, 1.0))

	# Shake is added on top of the lean, then fades out.
	var shake_offset := Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * _shake
	camera.offset = _camera_lean + shake_offset
	_shake = move_toward(_shake, 0.0, shake_decay * delta)


## Only touches `visual`'s transform/colour, never its children, so swapping
## in real sprites later needs no changes here.
func _update_visuals() -> void:
	if state == State.ROLLING:
		var t := clampf(_roll_time / roll_duration, 0.0, 1.0)
		var spin_dir := signf(_roll_direction.x) if _roll_direction.x != 0.0 else 1.0
		visual.rotation = spin_dir * TAU * t
		var squash := 0.15 * sin(PI * t)
		visual.scale = Vector2(1.0 + squash, 1.0 - squash)
	else:
		visual.rotation = 0.0
		visual.scale = Vector2.ONE

	# Red tint after being hit, half-transparent while invincible (so you can
	# see the i-frames working).
	var tint := Color(1.0, 0.45, 0.45) if _hurt_iframes_left > 0.0 else Color.WHITE
	tint.a = 0.5 if is_invincible() else 1.0
	visual.modulate = tint

	# Muzzle flash: visible for a few frames after each shot.
	_flash_left = maxf(0.0, _flash_left - get_physics_process_delta_time())
	muzzle.get_node("Flash").visible = _flash_left > 0.0


# --- Public API (called by enemies, bullets, pickups, UI) --------------------

func is_invincible() -> bool:
	var rolling_protected := state == State.ROLLING and _roll_time < roll_iframes
	return rolling_protected or _hurt_iframes_left > 0.0 or _blank_iframes_left > 0.0 or state == State.DEAD


## Called by enemy bullets and hazards. Damage is in half-hearts; fractions
## round up so every hit costs at least something.
## Returns true if the hit landed, false if the dodge roll (or recent hit) dodged it.
func take_damage(amount: float) -> bool:
	if is_invincible():
		return false
	health = maxi(0, health - ceili(amount))
	_hurt_iframes_left = hurt_iframes
	add_shake(5.0)
	health_changed.emit(health, max_health)
	if health == 0:
		state = State.DEAD
		died.emit()
	return true


## Uses the closest thing in range that can be used (flip a table, open a
## chest, take stairs...). Anything usable joins the "interactables" group and
## provides can_interact(player) and interact(player). Returns true if
## something was used.
func try_interact() -> bool:
	var best: Node2D = null
	var best_distance := interact_range
	for node in get_tree().get_nodes_in_group("interactables"):
		var candidate := node as Node2D
		if candidate == null or not candidate.has_method("can_interact") or not candidate.can_interact(self):
			continue
		var distance := global_position.distance_to(candidate.global_position)
		if distance <= best_distance:
			best_distance = distance
			best = candidate
	if best == null:
		return false
	best.interact(self)
	return true


## Spends one blank: destroys nearby enemy bullets, pushes enemies back and
## grants a moment of invincibility. Works mid-roll. Returns false if there is
## no blank to spend (or we are dead / still in the double-tap cooldown).
func use_blank() -> bool:
	if blanks <= 0 or state == State.DEAD or _blank_cooldown_left > 0.0:
		return false
	blanks -= 1
	_blank_cooldown_left = blank_cooldown
	_blank_iframes_left = blank_iframes
	BlankEffect.fire(get_parent(), global_position, blank_radius, blank_knockback)
	add_shake(4.0)
	blanks_changed.emit(blanks, max_blanks)
	return true


## For pickups and shops. Returns how many were actually added (the player
## can't carry more than max_blanks).
func add_blanks(amount: int) -> int:
	var before := blanks
	blanks = clampi(blanks + amount, 0, max_blanks)
	blanks_changed.emit(blanks, max_blanks)
	return blanks - before


func heal(amount: int) -> void:
	health = mini(max_health, health + amount)
	health_changed.emit(health, max_health)


## Camera shake in pixels. The strongest recent shake wins, so rapid fire
## doesn't stack into a seizure.
func add_shake(amount: float) -> void:
	_shake = maxf(_shake, amount)


func play_muzzle_flash() -> void:
	_flash_left = 0.05


## Tints the placeholder gun so you can see which weapon is equipped. With real
## art this becomes "swap the weapon sprite".
func set_gun_color(color: Color) -> void:
	# Looked up directly (not via an @onready var) because WeaponManager calls
	# this during its own _ready, which runs before the Player's.
	var gun := get_node("AimPivot/GunPlaceholder") as Polygon2D
	gun.color = color


## One-line status used by the test room's debug label.
func debug_text() -> String:
	return "state: %s\nhealth: %d/%d  blanks: %d\ninvincible: %s\ninput: %s" % [
		State.keys()[state],
		health,
		max_health,
		blanks,
		str(is_invincible()),
		"gamepad" if using_gamepad else "mouse + keyboard",
	]
