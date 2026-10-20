class_name Boss
extends Enemy
## A boss: an Enemy with a big health pool that fights in PHASES.
##
## It reuses everything from Enemy (state machine, windup flash, bullets,
## pathfinding, knockback immunity is up to the scene). What it adds:
##   - `phases` (BossPhase resources): when health drops below a phase's
##     threshold the boss switches movement and attack list. On the switch it
##     wipes the bullets on screen and is untouchable for a moment ("phase
##     pause"), so the player gets a breather and a clear signal.
##   - inside a phase it cycles through the phase's attacks in order.
##   - signals the HUD listens to (boss_health_changed, phase_changed).
##   - a guaranteed reward when it dies.
##
## A new boss is a scene inheriting enemy.tscn with this script, a few BossPhase
## resources and bigger numbers. Boss bar: see ui/hud/boss_bar.gd (it finds
## bosses through the "bosses" group, so nothing needs wiring).

signal boss_health_changed(current: float, maximum: float)
signal phase_changed(index: int)
## Emitted once when the boss dies (the `died` signal of Enemy also fires).
signal defeated

@export_group("Boss")
@export var boss_name: String = "Boss"
@export var phases: Array[BossPhase] = []
## Seconds of invulnerability and no attacks when a new phase begins.
@export var phase_pause: float = 1.0
## Reward at death: heart containers and coins (Pickup.Kind.HEART_CONTAINER).
@export var reward_heart_containers: int = 1
@export var reward_coins: int = 12

var phase_index: int = -1

var _attack_cycle: int = 0
var _pause_left: float = 0.0


func _ready() -> void:
	super()
	add_to_group("bosses")
	if not phases.is_empty():
		_enter_phase(0, false)


func _physics_process(delta: float) -> void:
	_pause_left = maxf(0.0, _pause_left - delta)
	super(delta)


# --- Health and phases ---------------------------------------------------------------

func take_damage(amount: float) -> bool:
	if _pause_left > 0.0:
		return false   # breather between phases: shots pass through
	var landed := super(amount)
	if landed:
		boss_health_changed.emit(maxf(health, 0.0), max_health)
		if state != State.DEAD:
			_check_phase()
	return landed


func _check_phase() -> void:
	var fraction := health / max_health
	var wanted := phase_index
	for i in phases.size():
		if fraction <= phases[i].health_threshold:
			wanted = i
	if wanted > phase_index:
		_enter_phase(wanted, true)


## Applies phase `index`. `announce` = a real switch mid-fight (pause, clear
## the bullets) as opposed to the opening phase.
func _enter_phase(index: int, announce: bool) -> void:
	phase_index = index
	var phase := phases[index]
	movement = phase.movement
	move_speed = phase.move_speed
	preferred_distance = phase.preferred_distance
	_attack_cycle = 0
	attack = phase.attacks[0] if not phase.attacks.is_empty() else null
	if announce:
		_pause_left = phase_pause
		state = State.IDLE            # abandon any attack in progress
		_cooldown_left = phase_pause + 0.5
		_clear_hostile_bullets()
		var player := get_tree().get_first_node_in_group("player") as Player
		if player:
			player.add_shake(6.0)
	phase_changed.emit(index)


## Next attack of the phase, round and round. Runs after every attack.
func _end_attack() -> void:
	super()
	var phase := phases[phase_index] if phase_index >= 0 else null
	if phase != null and phase.attacks.size() > 1:
		_attack_cycle = (_attack_cycle + 1) % phase.attacks.size()
		attack = phase.attacks[_attack_cycle]


func _wants_to_attack() -> bool:
	return _pause_left <= 0.0 and super()


# --- Death ------------------------------------------------------------------------------

func _die() -> void:
	_clear_hostile_bullets()
	super()
	defeated.emit()


## Replaces the random drops with a fixed reward.
func _drop_loot() -> void:
	var holder: Node = _room if _room != null else get_parent()
	for i in reward_heart_containers:
		Pickup.spawn(holder, global_position + Vector2(-20.0 + 40.0 * i, 30.0), Pickup.Kind.HEART_CONTAINER)
	Pickup.spawn(holder, global_position + Vector2(0.0, 44.0), Pickup.Kind.HEART)
	for i in reward_coins:
		var angle := TAU * float(i) / float(maxi(reward_coins, 1))
		Pickup.spawn(holder, global_position + Vector2.from_angle(angle) * 36.0, Pickup.Kind.COIN)


## Removes every enemy bullet (the player's own are kept).
func _clear_hostile_bullets() -> void:
	for node in get_tree().get_nodes_in_group("bullets"):
		var bullet := node as Bullet
		if bullet != null and bullet.is_hostile():
			bullet.destroy()


func _update_visuals() -> void:
	super()
	# During the phase pause the boss glows, so the breather is readable.
	if _pause_left > 0.0 and state != State.DEAD:
		var pulse := 0.5 + 0.5 * sin(_pause_left * 14.0)
		visual.modulate = Color(1.0, 0.5 + 0.4 * pulse, 0.5 + 0.4 * pulse)
