class_name FloorBuilder
extends Node2D
## Turns a FloorLayout (pure data) into real, connected rooms.
##
##     var builder := FloorBuilder.new()
##     add_child(builder)
##     builder.build(FloorGenerator.generate(seed, floor_index))
##     player.global_position = builder.start_room().global_position
##
## For every cell it creates a Room (type decides size, tint and contents),
## and for every doorway pair a Corridor between the two rooms. The doors
## belong to the rooms, so linking is just "both rooms have an exit on the
## facing sides". Contents are random but seeded: same layout, same floor.
##
## Boss, shop and treasure rooms are empty shells for now; 8c/8d/9a fill them.

## Distance between room CENTERS on the grid (fits the biggest room + a corridor).
const CELL_PITCH := Vector2(768.0, 560.0)

const ROOM_SIZES := {
	FloorLayout.RoomType.START: Vector2(320, 224),
	FloorLayout.RoomType.COMBAT: Vector2(480, 320),
	FloorLayout.RoomType.SHOP: Vector2(320, 224),
	FloorLayout.RoomType.TREASURE: Vector2(320, 224),
	FloorLayout.RoomType.BOSS: Vector2(640, 420),
}
const ROOM_COLORS := {
	FloorLayout.RoomType.START: Color(0.13, 0.17, 0.2),
	FloorLayout.RoomType.COMBAT: Color(0.13, 0.14, 0.18),
	FloorLayout.RoomType.SHOP: Color(0.18, 0.17, 0.1),
	FloorLayout.RoomType.TREASURE: Color(0.15, 0.12, 0.2),
	FloorLayout.RoomType.BOSS: Color(0.2, 0.1, 0.1),
}
## Enemy pool for combat rooms. Later floors can unlock more.
const ENEMY_POOL: Array[String] = [
	"res://entities/enemies/bullet_kin.tscn",
	"res://entities/enemies/bullet_kin.tscn",
	"res://entities/enemies/shotgun_kin.tscn",
	"res://entities/enemies/ring_turret.tscn",
	"res://entities/enemies/spiral_mage.tscn",
]
const PILLAR_SCENE: PackedScene = preload("res://levels/rooms/pillar.tscn")
const TABLE_SCENE: PackedScene = preload("res://levels/props/table.tscn")
## Prop spots, all clear of the door lines through the room's middle.
const PILLAR_SPOTS := [Vector2(-90, -60), Vector2(90, -60), Vector2(-90, 60), Vector2(90, 60)]
const TABLE_SPOTS := [Vector2(-150, -110), Vector2(150, -110), Vector2(-150, 110), Vector2(150, 110)]

var layout: FloorLayout
## Vector2i grid position -> Room
var rooms: Dictionary = {}
var corridors: Array[Corridor] = []


## Builds everything for `new_layout`. Call once per builder.
func build(new_layout: FloorLayout) -> void:
	layout = new_layout
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([layout.seed_used, layout.floor_index, "contents"])
	# Sorted so the random stream is used in the same order every time.
	var positions: Array = layout.cells.keys()
	positions.sort_custom(func(a, b): return a.y < b.y if a.y != b.y else a.x < b.x)
	for pos in positions:
		_build_room(layout.cells[pos], rng)
	for pos in positions:
		_build_corridors(layout.cells[pos])


func start_room() -> Room:
	return rooms.get(layout.start_pos)


func boss_room() -> Room:
	return rooms.get(layout.boss_pos)


## World position of a grid cell's room center.
static func cell_to_world(pos: Vector2i) -> Vector2:
	return Vector2(pos.x * CELL_PITCH.x, pos.y * CELL_PITCH.y)


func _build_room(cell: FloorLayout.Cell, rng: RandomNumberGenerator) -> void:
	var room := Room.new()
	room.name = "Room_%d_%d" % [cell.grid_pos.x, cell.grid_pos.y]
	room.size = ROOM_SIZES[cell.type]
	room.exits = cell.exits              # same bit values as Room.Exit
	room.floor_color = ROOM_COLORS[cell.type]
	room.position = cell_to_world(cell.grid_pos)   # position BEFORE add_child
	room.set_meta("room_type", cell.type)
	room.set_meta("grid_pos", cell.grid_pos)   # the minimap maps Room -> cell with this
	if cell.type == FloorLayout.RoomType.COMBAT:
		room.waves = _make_waves(rng)
	add_child(room)
	# Props go in after add_child: they are just children on the world layer.
	if cell.type == FloorLayout.RoomType.COMBAT:
		_add_props(room, rng)
	rooms[cell.grid_pos] = room


## 2 waves, a bit bigger on deeper floors.
func _make_waves(rng: RandomNumberGenerator) -> Array[RoomWave]:
	var waves: Array[RoomWave] = []
	for w in 2:
		var wave := RoomWave.new()
		var count := 2 + layout.floor_index + rng.randi_range(0, 2)
		for i in count:
			wave.enemies.append(load(ENEMY_POOL[rng.randi() % ENEMY_POOL.size()]))
		wave.delay = 1.0
		waves.append(wave)
	return waves


func _add_props(room: Room, rng: RandomNumberGenerator) -> void:
	for spot in PILLAR_SPOTS:
		if rng.randf() < 0.5:
			var pillar := PILLAR_SCENE.instantiate()
			pillar.position = spot
			room.add_child(pillar)
	var table_spots := TABLE_SPOTS.duplicate()
	for i in rng.randi_range(0, 2):
		var spot: Vector2 = table_spots.pop_at(rng.randi() % table_spots.size())
		var table := TABLE_SCENE.instantiate()
		table.position = spot
		room.add_child(table)


## One corridor per doorway pair. Only the east and south exits are handled
## here so each pair is made once (the neighbour's west/north is the same one).
func _build_corridors(cell: FloorLayout.Cell) -> void:
	for bit in [FloorLayout.EAST, FloorLayout.SOUTH]:
		var other := layout.neighbor(cell.grid_pos, bit)
		if other == null:
			continue
		var a: Room = rooms[cell.grid_pos]
		var b: Room = rooms[other.grid_pos]
		var horizontal: bool = bit == FloorLayout.EAST
		# The passage spans the gap between the two facing room edges.
		var from_edge := (a.size.x if horizontal else a.size.y) * 0.5
		var to_edge := (b.size.x if horizontal else b.size.y) * 0.5
		var span := (b.position - a.position).length()
		var corridor := Corridor.new()
		corridor.horizontal = horizontal
		# Corridors are added after the rooms, so without this their floor would
		# be painted OVER the rooms' doors and hide them.
		corridor.z_index = -1
		corridor.length = span - from_edge - to_edge
		var along := Vector2.RIGHT if horizontal else Vector2.DOWN
		corridor.position = a.position + along * (from_edge + corridor.length * 0.5)
		add_child(corridor)
		corridors.append(corridor)
