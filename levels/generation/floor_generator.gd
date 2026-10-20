class_name FloorGenerator
extends RefCounted
## Builds a FloorLayout from a seed. Same seed + floor index = same floor.
##
## How it works:
##  1. Start with one room and grow the map by attaching a new room next to a
##     random existing one. A candidate spot is rejected if it would touch more
##     than one existing room, which keeps the map branchy instead of a blob.
##  2. Rooms with a single door (other than the start) are dead ends.
##  3. The dead end farthest from the start becomes the boss room (you have to
##     cross the whole floor). Other dead ends become the shop and the treasure
##     room, so they are always optional detours.
##  4. If the shape has too few dead ends, throw it away and grow another one
##     (the attempt number is part of the random stream, so it stays repeatable).
##
## Everything tunable is a constant below.

const MIN_ROOMS := 8
## Rooms added per floor, so deeper floors are bigger.
const ROOMS_PER_FLOOR := 2
const MAX_ROOMS := 20
## A new room may touch at most this many existing rooms.
const MAX_TOUCHING := 1
const MAX_ATTEMPTS := 100
## A room never gets more than this many doors.
const MAX_EXITS := 3


static func room_count_for_floor(floor_index: int) -> int:
	return clampi(MIN_ROOMS + floor_index * ROOMS_PER_FLOOR, MIN_ROOMS, MAX_ROOMS)


static func generate(seed_value: int, floor_index: int = 0) -> FloorLayout:
	var wanted := room_count_for_floor(floor_index)
	for attempt in MAX_ATTEMPTS:
		var rng := RandomNumberGenerator.new()
		# Mix the floor and attempt in so each gets its own stream.
		rng.seed = hash([seed_value, floor_index, attempt])
		var layout := _try_generate(rng, wanted)
		if layout != null:
			layout.seed_used = seed_value
			layout.floor_index = floor_index
			return layout
	push_error("FloorGenerator: no valid layout after %d attempts" % MAX_ATTEMPTS)
	return null


static func _try_generate(rng: RandomNumberGenerator, wanted: int) -> FloorLayout:
	var layout := FloorLayout.new()
	var start := _make_cell(layout, Vector2i.ZERO)
	start.type = FloorLayout.RoomType.START

	# ---- 1. grow
	var guard := 0
	while layout.cells.size() < wanted and guard < 2000:
		guard += 1
		var from: FloorLayout.Cell = layout.cells.values()[rng.randi() % layout.cells.size()]
		if from.exit_count() >= MAX_EXITS:
			continue
		var bits := FloorLayout.STEPS.keys()
		var bit: int = bits[rng.randi() % bits.size()]
		var pos: Vector2i = from.grid_pos + FloorLayout.STEPS[bit]
		if layout.cells.has(pos) or _touching(layout, pos) > MAX_TOUCHING:
			continue
		var cell := _make_cell(layout, pos)
		from.exits |= bit
		cell.exits |= FloorLayout.opposite(bit)
	if layout.cells.size() < wanted:
		return null

	# ---- distances from the start (breadth first)
	var queue: Array = [start]
	var seen := {start.grid_pos: true}
	while not queue.is_empty():
		var cur: FloorLayout.Cell = queue.pop_front()
		for bit in FloorLayout.STEPS:
			if cur.exits & bit:
				var next: FloorLayout.Cell = layout.cells[cur.grid_pos + FloorLayout.STEPS[bit]]
				if not seen.has(next.grid_pos):
					seen[next.grid_pos] = true
					next.distance = cur.distance + 1
					queue.append(next)

	# ---- 2/3. dead ends -> boss, shop, treasure
	var dead_ends: Array = layout.cells.values().filter(
		func(c): return c != start and c.exit_count() == 1)
	if dead_ends.size() < 3:
		return null
	# Farthest first; ties broken by grid position so the result is deterministic.
	dead_ends.sort_custom(func(a, b):
		if a.distance != b.distance:
			return a.distance > b.distance
		return a.grid_pos.x < b.grid_pos.x if a.grid_pos.x != b.grid_pos.x else a.grid_pos.y < b.grid_pos.y)
	var boss: FloorLayout.Cell = dead_ends.pop_front()
	boss.type = FloorLayout.RoomType.BOSS
	layout.boss_pos = boss.grid_pos
	# Shuffle the rest with our own rng (Array.shuffle uses the global one).
	for i in range(dead_ends.size() - 1, 0, -1):
		var j := rng.randi() % (i + 1)
		var tmp = dead_ends[i]
		dead_ends[i] = dead_ends[j]
		dead_ends[j] = tmp
	dead_ends[0].type = FloorLayout.RoomType.SHOP
	dead_ends[1].type = FloorLayout.RoomType.TREASURE

	# The boss must not be next door to the start: make it a real trek.
	if boss.distance < 3:
		return null
	return layout


static func _make_cell(layout: FloorLayout, pos: Vector2i) -> FloorLayout.Cell:
	var cell := FloorLayout.Cell.new()
	cell.grid_pos = pos
	layout.cells[pos] = cell
	return cell


## How many existing rooms sit next to `pos`.
static func _touching(layout: FloorLayout, pos: Vector2i) -> int:
	var n := 0
	for bit in FloorLayout.STEPS:
		if layout.cells.has(pos + FloorLayout.STEPS[bit]):
			n += 1
	return n
