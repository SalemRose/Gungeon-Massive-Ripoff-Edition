extends Node
## The current RUN: which floor you are on and what you carry between floors.
## (An autoload named `Run`, so any script can say `Run.floor_index`.)
##
## A run = FLOORS_PER_RUN floors. Each floor is its own scene load; this node
## survives the reload and holds the seed of the run plus a snapshot of the
## player (health, blanks, coins, ammo...) that the next floor puts back.
##
##     Run.start_new_run()           # new seed, floor 0
##     Run.advance(player)           # remember the player, go one floor down
##     Run.apply(player)             # put the remembered state onto a new player
##     Run.reset()                   # run over (death or victory)
##
## Permanent progress between runs (unlocks, hub currency) is NOT here: that is
## the SaveData autoload (end_run() hands it the result of each run).

const FLOORS_PER_RUN := 3
## Hub currency rules (see reward_for).
const BASE_REWARD := 5
const FLOOR_REWARD := 10
const VICTORY_REWARD := 30

## True once a run has started (the first floor level starts one by itself).
var active: bool = false
var run_seed: int = 0
var floor_index: int = 0
## What the player carried out of the previous floor. Empty on floor 0.
var snapshot: Dictionary = {}
## Hub currency the last finished run paid out (the results screen shows it).
var last_reward: int = 0


## Begins a run. Pass a seed to repeat a run, or leave 0 for a random one.
func start_new_run(seed_value: int = 0) -> void:
	run_seed = seed_value if seed_value != 0 else (randi() % 1000000 + 1)
	floor_index = 0
	snapshot = {}
	active = true


func is_last_floor() -> bool:
	return floor_index >= FLOORS_PER_RUN - 1


## Stores the player's state and moves the run to the next floor.
func advance(player: Player) -> void:
	snapshot = capture(player)
	floor_index += 1


## Ends a run that was really played: records it in the permanent save
## (SaveData), then resets. Fixed-seed floors (tests / debug) have no run, so
## nothing is recorded for them. `SaveData` is looked up by path so this script
## also compiles in headless test scripts.
func end_run(victory: bool, player: Player = null) -> void:
	last_reward = 0
	if active:
		var save_node := get_node_or_null("/root/SaveData")
		if save_node != null:
			save_node.record_run(victory, floor_index + 1)
			last_reward = reward_for(victory, floor_index, player.coins if player != null else 0)
			save_node.add_to("currency", last_reward)
	reset()


## Hub currency earned by a run. Rewards progress even when you die:
## a base amount, a bonus per floor you fully cleared, a bonus for winning,
## and half of the coins you were still carrying (coins are otherwise lost).
static func reward_for(victory: bool, floor_index_reached: int, coins_left: int) -> int:
	var floors_cleared := floor_index_reached + (1 if victory else 0)
	return BASE_REWARD + floors_cleared * FLOOR_REWARD + (VICTORY_REWARD if victory else 0) + coins_left / 2


## Ends the run. The next floor level starts a fresh one.
func reset() -> void:
	active = false
	floor_index = 0
	snapshot = {}


## The parts of the player that carry over between floors.
func capture(player: Player) -> Dictionary:
	var guns: Array = []
	for weapon in player.weapon_manager.weapons:
		guns.append({"magazine": weapon.magazine, "reserve": weapon.reserve})
	return {
		"max_health": player.max_health,
		"health": player.health,
		"blanks": player.blanks,
		"salves": player.salves,
		"coins": player.coins,
		"weapon_index": player.weapon_manager.current_index,
		"guns": guns,
		"items": player.items.map(func(i: ItemData): return i.id),
	}


## Puts a snapshot back onto a fresh player (does nothing if it is empty).
func apply(player: Player) -> void:
	if snapshot.is_empty():
		return
	player.max_health = snapshot["max_health"]
	player.health = snapshot["health"]
	player.blanks = snapshot["blanks"]
	player.salves = snapshot.get("salves", player.salves)
	player.coins = snapshot["coins"]
	var weapons := player.weapon_manager.weapons
	for i in mini(weapons.size(), snapshot["guns"].size()):
		weapons[i].magazine = snapshot["guns"][i]["magazine"]
		weapons[i].reserve = snapshot["guns"][i]["reserve"]
	player.weapon_manager.switch_to(snapshot["weapon_index"])
	# Items: re-register them and their multipliers. We do NOT call add_item():
	# its flat bonuses (max health, blanks) are already inside the saved values.
	for item_id in snapshot.get("items", []):
		var item := ItemPool.find(item_id)
		if item != null:
			player.items.append(item)
			player.damage_mult *= item.damage_mult
			player.fire_rate_mult *= item.fire_rate_mult
			player.move_speed_mult *= item.move_speed_mult
	# Tell the HUD and anything else listening.
	player.health_changed.emit(player.health, player.max_health)
	player.blanks_changed.emit(player.blanks, player.max_blanks)
	player.coins_changed.emit(player.coins)
	player.salves_changed.emit(player.salves, player.max_salves)
