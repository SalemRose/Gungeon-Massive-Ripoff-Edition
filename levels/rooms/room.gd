class_name Room
extends Node2D
## One rectangular room: walls, doors at its exits, and a fight that locks the
## doors until every enemy wave is dead (the Gungeon loop).
##
## THE ROOM BUILDS ITSELF from a few numbers (size, exits, waves), so the floor
## generator can later create rooms in code just by setting those and adding
## the node. Extra props (pillars, tables) can be added as children in the
## editor; they only need to be on the "world" physics layer.
##
## ORIGIN: the node's position is the CENTER of the room's floor.
##
## LIFE CYCLE
##   IDLE      waiting for the player. A room with no enemies skips straight to
##             CLEARED and never locks (start room, treasure room...).
##   LOCKING   the player walked well inside. After `lock_delay` the doors
##             close. Stepping back out before that cancels it.
##   ACTIVE    doors shut, waves play one after another.
##   CLEARED   doors open for good; the room never locks again.
##
## SPAWNING: enemies appear at the room's SpawnPoints (Marker2D children, if
## you add a node called "SpawnPoints") or else on an automatic grid. Spots
## inside obstacles or next to doors are skipped, and spots far from the
## player are preferred, so you never get an enemy spawned on your head.

signal entered
signal locked
signal wave_started(index: int, total: int)
signal cleared

enum State { IDLE, LOCKING, ACTIVE, CLEARED }
## Bit flags: combine with | (e.g. EAST | WEST = 10). In the Inspector these
## are check boxes.
enum Exit { NORTH = 1, EAST = 2, SOUTH = 4, WEST = 8 }

const WALL_THICKNESS := 16.0
const DOOR_WIDTH := 48.0
const DOOR_SCENE: PackedScene = preload("res://levels/rooms/door.tscn")
## Physics layer masks: 1 = world, 2 = player.
const WORLD_MASK := 1
const PLAYER_MASK := 2
## Everything an enemy must not spawn inside: walls, pillars (layer 1) and
## tables (layer 8).
const OBSTACLE_MASK := 1 | 128

@export_group("Shape")
## Size of the floor in pixels (walls are built outside of it).
@export var size: Vector2 = Vector2(480.0, 320.0)
## Which sides have a doorway (centered on that side).
@export_flags("North:1", "East:2", "South:4", "West:8") var exits: int = 0

@export_group("Fight")
@export var waves: Array[RoomWave] = []
## Seconds between "player walked in" and "doors close".
@export var lock_delay: float = 0.5
## The player must be at least this far inside the walls to trigger the lock.
## It must be bigger than the player's reach in `lock_delay` so nobody is
## trapped half in a doorway.
@export var trigger_inset: float = 56.0

@export_group("Spawning")
## Preferred minimum distance between a spawned enemy and the player.
@export var min_spawn_distance: float = 150.0
## Automatic spawn grid: distance from the walls and between grid points.
@export var spawn_margin: float = 40.0
@export var spawn_spacing: float = 56.0
## Enemies don't spawn within this distance of a doorway.
@export var spawn_door_clearance: float = 90.0

@export_group("Look")
@export var floor_color: Color = Color(0.13, 0.14, 0.18)
@export var wall_color: Color = Color(0.32, 0.3, 0.38)

var state: State = State.IDLE
## Navigation grid: square cells this big (px), see "Navigation" below.
const NAV_CELL := 16.0
## Cells whose center is closer than this to an obstacle count as blocked,
## so a path always has room for an enemy body (radius ~9).
const NAV_CLEARANCE := 11.0
## The grid is rebuilt at most this often (a table may have broken meanwhile).
const NAV_REFRESH := 1.5

## Index of the wave currently (or last) played; -1 before the first.
var wave_index: int = -1
var doors: Array[Door] = []

var _walls_root: Node2D
var _doors_root: Node2D
var _enemy_root: Node2D
var _trigger: Area2D
var _exit_gaps: Array[Rect2] = []
## Enemies of the current wave still alive, keyed by instance id.
var _alive: Dictionary = {}
var _lock_left: float = 0.0
var _doors_requested: bool = false
var _wave_pending: bool = false
var _wave_timer: float = 0.0
var _player: Player
var _nav: AStarGrid2D
var _nav_cols: int = 0
var _nav_rows: int = 0
var _nav_time: float = -999.0


func _ready() -> void:
	add_to_group("rooms")
	_build()
	if not _has_enemies():
		_set_state(State.CLEARED)


# --- Building ---------------------------------------------------------------------

func _build() -> void:
	_walls_root = _add_container("Walls")
	_enemy_root = _add_container("Enemies")
	_doors_root = _add_container("Doors")

	for side in [Exit.NORTH, Exit.EAST, Exit.SOUTH, Exit.WEST]:
		_build_side(side)

	_trigger = Area2D.new()
	_trigger.name = "EntryTrigger"
	_trigger.collision_layer = 0
	_trigger.collision_mask = PLAYER_MASK
	_trigger.monitorable = false
	var trigger_shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = (size - Vector2.ONE * trigger_inset * 2.0).max(Vector2.ONE * 8.0)
	trigger_shape.shape = rect
	_trigger.add_child(trigger_shape)
	add_child(_trigger)


func _add_container(container_name: String) -> Node2D:
	var node := Node2D.new()
	node.name = container_name
	add_child(node)
	return node


## Builds the wall (or the two wall pieces around a doorway) for one side.
func _build_side(side: int) -> void:
	var half := size * 0.5
	var t := WALL_THICKNESS
	var horizontal := side == Exit.NORTH or side == Exit.SOUTH

	# The full wall strip for this side. North/south strips cover the corners.
	var strip := Rect2()
	match side:
		Exit.NORTH:
			strip = Rect2(-half.x - t, -half.y - t, size.x + 2.0 * t, t)
		Exit.SOUTH:
			strip = Rect2(-half.x - t, half.y, size.x + 2.0 * t, t)
		Exit.EAST:
			strip = Rect2(half.x, -half.y, t, size.y)
		Exit.WEST:
			strip = Rect2(-half.x - t, -half.y, t, size.y)

	if not (exits & side):
		_add_wall(strip)
		return

	var gap_size := Vector2(DOOR_WIDTH, t) if horizontal else Vector2(t, DOOR_WIDTH)
	var gap := Rect2(strip.get_center() - gap_size * 0.5, gap_size)
	if horizontal:
		_add_wall(Rect2(strip.position, Vector2(gap.position.x - strip.position.x, t)))
		_add_wall(Rect2(Vector2(gap.end.x, strip.position.y), Vector2(strip.end.x - gap.end.x, t)))
	else:
		_add_wall(Rect2(strip.position, Vector2(t, gap.position.y - strip.position.y)))
		_add_wall(Rect2(Vector2(strip.position.x, gap.end.y), Vector2(t, strip.end.y - gap.end.y)))

	_exit_gaps.append(gap)
	var door := DOOR_SCENE.instantiate() as Door
	_doors_root.add_child(door)
	door.position = gap.get_center()
	door.setup(gap.size)
	doors.append(door)


func _add_wall(rect: Rect2) -> void:
	if rect.size.x <= 0.0 or rect.size.y <= 0.0:
		return
	var body := StaticBody2D.new()
	body.collision_layer = WORLD_MASK
	body.collision_mask = 0
	body.position = rect.get_center()

	var collider := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = rect.size
	collider.shape = shape
	body.add_child(collider)

	# Everything visible sits under `Visual` so final art can replace it.
	var art := Node2D.new()
	art.name = "Visual"
	var polygon := Polygon2D.new()
	polygon.color = wall_color
	var half := rect.size * 0.5
	polygon.polygon = PackedVector2Array([-half, Vector2(half.x, -half.y), half, Vector2(-half.x, half.y)])
	art.add_child(polygon)
	body.add_child(art)

	_walls_root.add_child(body)


## Floor, plus a colored border that shows the fight state.
func _draw() -> void:
	var floor_rect := Rect2(-size * 0.5, size)
	draw_rect(floor_rect, floor_color)
	for gap in _exit_gaps:
		draw_rect(gap, floor_color)
	match state:
		State.LOCKING, State.ACTIVE:
			draw_rect(floor_rect, Color(0.9, 0.25, 0.25, 0.55), false, 2.0)
		State.CLEARED:
			if _has_enemies():
				draw_rect(floor_rect, Color(0.3, 0.85, 0.45, 0.35), false, 2.0)


# --- The fight ----------------------------------------------------------------------

func _physics_process(delta: float) -> void:
	match state:
		State.IDLE:
			if _player_inside():
				_begin_locking()
		State.LOCKING:
			_process_locking(delta)
		State.ACTIVE:
			_process_active(delta)


func _begin_locking() -> void:
	_lock_left = lock_delay
	_doors_requested = false
	_set_state(State.LOCKING)
	entered.emit()


func _process_locking(delta: float) -> void:
	if not _doors_requested:
		if not _player_inside():
			_set_state(State.IDLE)  # stepped back out in time: nothing happens
			return
		_lock_left -= delta
		if _lock_left <= 0.0:
			_doors_requested = true
			for door in doors:
				door.close()
	elif doors.all(func(door: Door) -> bool: return door.is_closed):
		_begin_fight()


func _begin_fight() -> void:
	wave_index = -1
	_wave_pending = true
	_wave_timer = _wave_delay(0)
	_set_state(State.ACTIVE)
	locked.emit()


func _process_active(delta: float) -> void:
	if _wave_pending:
		_wave_timer -= delta
		if _wave_timer <= 0.0:
			_wave_pending = false
			_start_next_wave()
		return
	if not _alive.is_empty():
		return
	# Current wave is dead.
	if wave_index + 1 < waves.size():
		_wave_pending = true
		_wave_timer = _wave_delay(wave_index + 1)
	else:
		_clear()


func _start_next_wave() -> void:
	wave_index += 1
	var wave := waves[wave_index]
	if wave != null:
		_spawn_wave(wave)
	wave_started.emit(wave_index, waves.size())


func _clear() -> void:
	for door in doors:
		door.open()
	_set_state(State.CLEARED)
	cleared.emit()


func _set_state(new_state: State) -> void:
	state = new_state
	queue_redraw()


func _wave_delay(index: int) -> float:
	return waves[index].delay if waves[index] != null else 0.0


func _has_enemies() -> bool:
	for wave in waves:
		if wave != null and not wave.enemies.is_empty():
			return true
	return false


func _player_inside() -> bool:
	for body in _trigger.get_overlapping_bodies():
		var player := body as Player
		if player and player.state != Player.State.DEAD:
			return true
	return false


# --- Spawning -------------------------------------------------------------------------

func _spawn_wave(wave: RoomWave) -> void:
	var spots := _pick_spawn_points(wave.enemies.size())
	for i in wave.enemies.size():
		var scene := wave.enemies[i]
		if scene == null:
			continue
		var enemy := scene.instantiate() as Enemy
		if enemy == null:
			push_warning("Room %s: wave %d contains a scene that is not an Enemy" % [name, wave_index])
			continue
		enemy.auto_activate = false  # the room wakes it up
		# Position BEFORE adding to the tree: an enemy added first sits at the
		# container's origin for a moment, and if the player is standing there
		# the physics engine would shove the player out of the way.
		enemy.position = _enemy_root.to_local(spots[i])
		_enemy_root.add_child(enemy)
		_alive[enemy.get_instance_id()] = enemy
		# Count it as gone when it dies OR when it is removed in any other way
		# (so a room can never get stuck waiting for a freed enemy).
		enemy.died.connect(_on_enemy_gone)
		enemy.tree_exiting.connect(_on_enemy_gone.bind(enemy))
		enemy.activate()


func _on_enemy_gone(enemy: Enemy) -> void:
	_alive.erase(enemy.get_instance_id())


## `count` positions: far from the player first, never inside obstacles.
## If there are more enemies than free spots, spots are reused with a jitter.
func _pick_spawn_points(count: int) -> Array[Vector2]:
	var spots := _spawn_candidates()
	spots.shuffle()

	var player := _find_player()
	if player:
		var far: Array[Vector2] = []
		var near: Array[Vector2] = []
		for spot in spots:
			if spot.distance_to(player.global_position) >= min_spawn_distance:
				far.append(spot)
			else:
				near.append(spot)
		var origin := player.global_position
		near.sort_custom(func(a: Vector2, b: Vector2) -> bool: return a.distance_to(origin) > b.distance_to(origin))
		spots = far + near

	var result: Array[Vector2] = []
	for i in count:
		if spots.is_empty():
			result.append(global_position)
		elif i < spots.size():
			result.append(spots[i])
		else:
			result.append(spots[i % spots.size()] + Vector2(randf_range(-14.0, 14.0), randf_range(-14.0, 14.0)))
	return result


func _spawn_candidates() -> Array[Vector2]:
	var raw: Array[Vector2] = []
	var markers := get_node_or_null("SpawnPoints")
	if markers:
		for marker in markers.get_children():
			if marker is Node2D:
				raw.append((marker as Node2D).global_position)
	else:
		var limit := size * 0.5 - Vector2.ONE * spawn_margin
		var x := -limit.x
		while x <= limit.x + 0.01:
			var y := -limit.y
			while y <= limit.y + 0.01:
				var local := Vector2(x, y)
				if not _near_doorway(local):
					raw.append(to_global(local))
				y += spawn_spacing
			x += spawn_spacing

	var free: Array[Vector2] = []
	for spot in raw:
		if _is_spot_free(spot):
			free.append(spot)
	return free


func _near_doorway(local: Vector2) -> bool:
	for gap in _exit_gaps:
		if local.distance_to(gap.get_center()) < spawn_door_clearance:
			return true
	return false


## True when an enemy-sized circle at `spot` touches no wall or prop.
func _is_spot_free(spot: Vector2) -> bool:
	var circle := CircleShape2D.new()
	circle.radius = 12.0
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = circle
	query.transform = Transform2D(0.0, spot)
	query.collision_mask = OBSTACLE_MASK
	return get_world_2d().direct_space_state.intersect_shape(query, 1).is_empty()


# --- Navigation -----------------------------------------------------------------------
# A grid over the floor, A* on top. Cells touching a wall, pillar or table are
# solid. Enemies ask for a path only when they cannot walk straight at their
# goal (see Enemy._steer_direction), so the cost stays small. The grid is
# built on the first question and refreshed now and then.

## Path from `from` to `to` (global positions) around obstacles: a list of
## waypoints, empty if there is no way. Start and goal are moved to the
## nearest free cell if they sit in a blocked one.
func nav_path(from: Vector2, to: Vector2) -> PackedVector2Array:
	_nav_ensure()
	var a := _nav_nearest_free(_nav_cell(from))
	var b := _nav_nearest_free(_nav_cell(to))
	var result := PackedVector2Array()
	if a.x < 0 or b.x < 0:
		return result
	for cell in _nav.get_id_path(a, b):
		result.append(_nav_cell_center(cell))
	return result


## True when walking the straight line from `from` to `to` (global) stays on
## free cells, i.e. no obstacle is in the way.
func nav_line_clear(from: Vector2, to: Vector2) -> bool:
	_nav_ensure()
	var steps := maxi(int(from.distance_to(to) / (NAV_CELL * 0.5)), 1)
	for i in steps + 1:
		var cell := _nav_cell(from.lerp(to, float(i) / steps))
		if not _nav.is_in_boundsv(cell) or _nav.is_point_solid(cell):
			return false
	return true


func _nav_cell(global_point: Vector2) -> Vector2i:
	var local := to_local(global_point) + size * 0.5
	return Vector2i(floori(local.x / NAV_CELL), floori(local.y / NAV_CELL))


func _nav_cell_center(cell: Vector2i) -> Vector2:
	return to_global((Vector2(cell) + Vector2(0.5, 0.5)) * NAV_CELL - size * 0.5)


func _nav_ensure() -> void:
	var now := Time.get_ticks_msec() / 1000.0
	if _nav != null and now - _nav_time < NAV_REFRESH:
		return
	_nav_time = now
	_nav_cols = ceili(size.x / NAV_CELL)
	_nav_rows = ceili(size.y / NAV_CELL)
	if _nav == null:
		_nav = AStarGrid2D.new()
		_nav.cell_size = Vector2(NAV_CELL, NAV_CELL)
		_nav.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
		_nav.region = Rect2i(0, 0, _nav_cols, _nav_rows)
		_nav.update()
	var circle := CircleShape2D.new()
	circle.radius = NAV_CLEARANCE
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = circle
	query.collision_mask = OBSTACLE_MASK
	var space := get_world_2d().direct_space_state
	for x in _nav_cols:
		for y in _nav_rows:
			query.transform = Transform2D(0.0, _nav_cell_center(Vector2i(x, y)))
			_nav.set_point_solid(Vector2i(x, y), not space.intersect_shape(query, 1).is_empty())


## `cell`, or the closest free cell within 3 steps; (-1, -1) if none.
func _nav_nearest_free(cell: Vector2i) -> Vector2i:
	cell = Vector2i(clampi(cell.x, 0, _nav_cols - 1), clampi(cell.y, 0, _nav_rows - 1))
	for ring in 4:
		var best := Vector2i(-1, -1)
		var best_dist := INF
		for dx in range(-ring, ring + 1):
			for dy in range(-ring, ring + 1):
				var c := cell + Vector2i(dx, dy)
				if _nav.is_in_boundsv(c) and not _nav.is_point_solid(c) and float(dx * dx + dy * dy) < best_dist:
					best = c
					best_dist = float(dx * dx + dy * dy)
		if best.x >= 0:
			return best
	return Vector2i(-1, -1)


func _find_player() -> Player:
	if not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player") as Player
	return _player


# --- Queries (HUD and debug read these) -----------------------------------------------

func get_enemies() -> Array[Enemy]:
	var list: Array[Enemy] = []
	for enemy in _alive.values():
		if is_instance_valid(enemy):
			list.append(enemy)
	return list


## Text for the HUD: empty unless a fight is running.
func status_text() -> String:
	if state != State.ACTIVE:
		return ""
	return "WAVE %d / %d     ENEMIES %d" % [maxi(wave_index + 1, 1), waves.size(), _alive.size()]


func debug_text() -> String:
	return "%s: %s  wave %d/%d  alive %d" % [name, State.keys()[state], maxi(wave_index + 1, 0), waves.size(), _alive.size()]
