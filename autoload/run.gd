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
## the save system, step 12.

const FLOORS_PER_RUN := 3

## True once a run has started (the first floor level starts one by itself).
var active: bool = false
var run_seed: int = 0
var floor_index: int = 0
## What the player carried out of the previous floor. Empty on floor 0.
var snapshot: Dictionary = {}


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
		"coins": player.coins,
		"weapon_index": player.weapon_manager.current_index,
		"guns": guns,
	}


## Puts a snapshot back onto a fresh player (does nothing if it is empty).
func apply(player: Player) -> void:
	if snapshot.is_empty():
		return
	player.max_health = snapshot["max_health"]
	player.health = snapshot["health"]
	player.blanks = snapshot["blanks"]
	player.coins = snapshot["coins"]
	var weapons := player.weapon_manager.weapons
	for i in mini(weapons.size(), snapshot["guns"].size()):
		weapons[i].magazine = snapshot["guns"][i]["magazine"]
		weapons[i].reserve = snapshot["guns"][i]["reserve"]
	player.weapon_manager.switch_to(snapshot["weapon_index"])
	# Tell the HUD and anything else listening.
	player.health_changed.emit(player.health, player.max_health)
	player.blanks_changed.emit(player.blanks, player.max_blanks)
	player.coins_changed.emit(player.coins)
