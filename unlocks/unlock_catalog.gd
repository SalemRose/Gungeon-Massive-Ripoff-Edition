class_name UnlockCatalog
extends RefCounted
## All permanent unlocks, and the rules for buying and checking them.
## Static helpers only (nothing to instance). Progress is stored in SaveData.
##
##     UnlockCatalog.is_available(UnlockData.Kind.GUN, &"seeker")  # may it appear in a run?
##     UnlockCatalog.can_buy(&"gun_seeker")                         # enough currency, not owned?
##     UnlockCatalog.purchase(&"gun_seeker")                        # pay + unlock, returns bool
##
## DEV SWITCH: start the game with `-- --unlock-all` to treat everything as
## unlocked (handy for testing; the automated tests use it).

const FOLDER := "res://unlocks/data/"

static var _cache: Array[UnlockData] = []
static var _loaded: bool = false


## Every unlock, sorted by cost then id (the order the hub shop will show).
static func all() -> Array[UnlockData]:
	if not _loaded:
		_loaded = true
		_cache.clear()
		for file_name in DirAccess.get_files_at(FOLDER):
			file_name = file_name.trim_suffix(".remap")   # exported builds
			if file_name.ends_with(".tres"):
				var entry := load(FOLDER + file_name) as UnlockData
				if entry != null:
					_cache.append(entry)
		_cache.sort_custom(func(a: UnlockData, b: UnlockData):
			return a.cost < b.cost if a.cost != b.cost else String(a.id) < String(b.id))
	return _cache


static func find(unlock_id: StringName) -> UnlockData:
	for entry in all():
		if entry.id == unlock_id:
			return entry
	return null


static func unlock_all_flag() -> bool:
	return OS.get_cmdline_user_args().has("--unlock-all")


## The id of a gun: its .tres file name without the extension.
static func gun_id(data: WeaponData) -> StringName:
	return StringName(data.resource_path.get_file().get_basename())


## True if the gun / item may appear in a run: it has no unlock entry (always
## available) or its entry has been bought.
static func is_available(kind: UnlockData.Kind, target: StringName) -> bool:
	if unlock_all_flag():
		return true
	for entry in all():
		if entry.kind == kind and entry.target == target:
			return _save().is_unlocked(entry.id)
	return true


static func is_owned(unlock_id: StringName) -> bool:
	return unlock_all_flag() or _save().is_unlocked(unlock_id)


static func can_buy(unlock_id: StringName) -> bool:
	var entry := find(unlock_id)
	return entry != null and not is_owned(unlock_id) and int(_save().get_value("currency")) >= entry.cost


## Pays and unlocks. Returns false (and changes nothing) if it cannot be bought.
static func purchase(unlock_id: StringName) -> bool:
	if not can_buy(unlock_id):
		return false
	var entry := find(unlock_id)
	_save().add_to("currency", -entry.cost)
	_save().unlock(unlock_id)
	return true


## The SaveData autoload, looked up by path so this script also compiles in
## headless test scripts (where autoload names are not visible).
static func _save() -> Node:
	return (Engine.get_main_loop() as SceneTree).root.get_node("SaveData")
