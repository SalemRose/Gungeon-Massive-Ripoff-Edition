class_name ItemPool
extends RefCounted
## Finds every ItemData in res://items/data/ and rolls random ones.
##
## Static helpers only, nothing to instance:
##
##     var item := ItemPool.roll(rng, owned_ids)   # a random item you do not own
##     var item := ItemPool.find(&"heavy_rounds")  # by id (used by the run snapshot)
##
## Dropping a new .tres into items/data/ is enough to add it to chests and shops.

const FOLDER := "res://items/data/"

static var _cache: Array[ItemData] = []
static var _loaded: bool = false


## Every item, sorted by id (a stable order keeps seeded rolls reproducible).
static func all() -> Array[ItemData]:
	if not _loaded:
		_loaded = true
		_cache.clear()
		for file_name in DirAccess.get_files_at(FOLDER):
			# Exported games list resources as "name.tres.remap": strip that.
			file_name = file_name.trim_suffix(".remap")
			if file_name.ends_with(".tres"):
				var item := load(FOLDER + file_name) as ItemData
				if item != null:
					_cache.append(item)
		_cache.sort_custom(func(a: ItemData, b: ItemData): return String(a.id) < String(b.id))
	return _cache


static func find(item_id: StringName) -> ItemData:
	for item in all():
		if item.id == item_id:
			return item
	return null


## A random item whose id is not in `exclude`. Returns null if none are left.
static func roll(rng: RandomNumberGenerator, exclude: Array = []) -> ItemData:
	var candidates: Array[ItemData] = []
	for item in all():
		if not exclude.has(item.id):
			candidates.append(item)
	if candidates.is_empty():
		return null
	return candidates[rng.randi() % candidates.size()]
