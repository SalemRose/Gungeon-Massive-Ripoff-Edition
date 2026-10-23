extends Node
## PERMANENT progress: what survives between runs and between game sessions.
## (An autoload named `SaveData`.) Run-only state (health, items, floor...) lives
## in `Run` and is thrown away when the run ends; only this file is kept.
##
##     SaveData.get_value("currency")             # read
##     SaveData.set_value("currency", 40)         # write (saved to disk at once)
##     SaveData.add_to("currency", 5)             # numbers: add and save
##     SaveData.unlock(&"gun_seeker")             # remember an unlock
##     SaveData.is_unlocked(&"gun_seeker")
##     SaveData.record_run(true, 3)               # stats at the end of a run
##
## STORAGE: one JSON file in the user's data folder (user://save.json).
##  * VERSIONED: `version` lets a later game change the format (see _migrate).
##  * SAFE WRITES: written to save.json.tmp first, then renamed over the real
##    file, so a crash mid-write can never leave a half-written save.
##  * CORRUPT FILE: if the file cannot be read, it is kept as save.json.bad
##    (never silently deleted) and the game starts from a fresh save.
##  * MISSING KEYS: values are merged over DEFAULTS, so a save from an older
##    version simply gets the new keys with their default values.

signal changed
signal loaded

const VERSION := 1
## Every key the game knows about, with its starting value.
const DEFAULTS := {
	"version": VERSION,
	# Hub currency earned across runs (spent on unlocks in step 12b).
	"currency": 0,
	# Ids of things unlocked permanently (guns, items, hub upgrades...).
	"unlocks": [],
	# Lifetime statistics.
	"runs_played": 0,
	"victories": 0,
	"deaths": 0,
	"best_floor": 0,
	# Options (step 13b fills these in).
	"settings": {},
}

## Where the save lives. Tests point this somewhere else.
var path: String = "user://save.json"
var data: Dictionary = {}


func _ready() -> void:
	load_game()


## Reads the file from disk (or starts fresh if there is none / it is broken).
func load_game() -> void:
	data = DEFAULTS.duplicate(true)
	if FileAccess.file_exists(path):
		var text := FileAccess.get_file_as_string(path)
		var parsed: Variant = JSON.parse_string(text)
		if parsed is Dictionary:
			_migrate(parsed)
			# Merge: defaults first, then whatever the file has.
			for key in parsed:
				data[key] = parsed[key]
			data["version"] = VERSION
		else:
			# Unreadable: keep a copy for the player / for debugging.
			push_warning("SaveData: %s is corrupt, backing it up and starting fresh." % path)
			DirAccess.copy_absolute(path, path + ".bad")
	loaded.emit()


## Writes everything to disk. Returns true on success.
func save_game() -> bool:
	var tmp := path + ".tmp"
	var file := FileAccess.open(tmp, FileAccess.WRITE)
	if file == null:
		push_warning("SaveData: cannot write %s (error %d)" % [tmp, FileAccess.get_open_error()])
		return false
	file.store_string(JSON.stringify(data, "\t"))
	file.close()
	# Rename is the "commit": the old save is replaced in one step.
	return DirAccess.rename_absolute(tmp, path) == OK


## True if there is anything worth keeping: a finished run, currency or an
## unlock. The main menu uses it to enable LOAD and to warn before NEW GAME.
func has_progress() -> bool:
	return int(data["runs_played"]) > 0 or int(data["currency"]) > 0 or not (data["unlocks"] as Array).is_empty()


## Throws away all progress (a "delete save" button, and tests).
func reset_all() -> void:
	data = DEFAULTS.duplicate(true)
	save_game()
	changed.emit()


# --- Access -------------------------------------------------------------------

func get_value(key: String, fallback: Variant = null) -> Variant:
	return data.get(key, fallback)


func set_value(key: String, value: Variant) -> void:
	data[key] = value
	save_game()
	changed.emit()


## Adds `amount` to a number and saves. Returns the new total.
func add_to(key: String, amount: int) -> int:
	var total: int = int(data.get(key, 0)) + amount
	set_value(key, total)
	return total


func unlock(id: StringName) -> void:
	var list: Array = data["unlocks"]
	if not list.has(String(id)):
		list.append(String(id))
		save_game()
		changed.emit()


func is_unlocked(id: StringName) -> bool:
	return (data["unlocks"] as Array).has(String(id))


## Called once when a run ends. `floors_reached` counts from 1.
func record_run(victory: bool, floors_reached: int) -> void:
	data["runs_played"] += 1
	if victory:
		data["victories"] += 1
	else:
		data["deaths"] += 1
	data["best_floor"] = maxi(int(data["best_floor"]), floors_reached)
	save_game()
	changed.emit()


## Upgrades an older file to the current format, in place. Nothing to do yet:
## when VERSION becomes 2, add `if parsed.get("version", 1) < 2: ...` here.
func _migrate(_parsed: Dictionary) -> void:
	pass
