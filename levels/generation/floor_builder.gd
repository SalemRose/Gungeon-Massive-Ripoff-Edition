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
const BOSS_SCENE: PackedScene = preload("res://entities/enemies/bosses/warden.tscn")
const CHEST_SCENE: PackedScene = preload("res://levels/props/chest.tscn")
const SHOP_ITEM_SCENE: PackedScene = preload("res://levels/props/shop_item.tscn")
const ITEM_PEDESTAL_SCENE: PackedScene = preload("res://levels/props/item_pedestal.tscn")
## Price of the passive item on offer in the shop.
const SHOP_ITEM_PRICE := 35
## What the shop sells: [pickup kind, price]. Left to right on the pedestals.
const SHOP_STOCK := [
	[Pickup.Kind.HEART, 12],
	[Pickup.Kind.AMMO, 15],
	[Pickup.Kind.BLANK, 20],
	[Pickup.Kind.SALVE, 18],
]
## Prop spots, all clear of the door lines through the room's middle.
const PILLAR_SPOTS := [Vector2(-90, -60), Vector2(90, -60), Vector2(-90, 60), Vector2(90, 60)]
const TABLE_SPOTS := [Vector2(-150, -110), Vector2(150, -110), Vector2(-150, 110), Vector2(150, 110)]

var layout: FloorLayout
## Item ids already placed on this floor (chest / shop), to avoid duplicates.
var _placed_items: Array = []
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
	elif cell.type == FloorLayout.RoomType.BOSS:
		room.waves = _make_boss_waves()
	add_child(room)
	# Props go in after add_child: they are just children on the world layer.
	if cell.type == FloorLayout.RoomType.COMBAT:
		_add_props(room, rng)
	elif cell.type == FloorLayout.RoomType.SHOP:
		_add_shop_stock(room, rng)
	elif cell.type == FloorLayout.RoomType.TREASURE:
		_add_chest(room, rng)
	rooms[cell.grid_pos] = room


## The boss room is one wave: just the boss. Clearing it = killing the boss.
func _make_boss_waves() -> Array[RoomWave]:
	var wave := RoomWave.new()
	wave.enemies.append(BOSS_SCENE)
	wave.delay = 1.5
	return [wave] as Array[RoomWave]


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


## Pedestals in a row above the room's middle line, clear of the doorways.
func _add_shop_stock(room: Room, rng: RandomNumberGenerator) -> void:
	# One extra pedestal: a random passive item.
	var offered := _roll_item(rng)
	var slots := SHOP_STOCK.size() + (1 if offered != null else 0)
	if offered != null:
		var ped := ITEM_PEDESTAL_SCENE.instantiate() as ItemPedestal
		ped.item = offered
		ped.price = SHOP_ITEM_PRICE
		ped.position = Vector2((SHOP_STOCK.size() - (slots - 1) * 0.5) * 80.0, -45.0)
		room.add_child(ped)
	for i in SHOP_STOCK.size():
		var item := SHOP_ITEM_SCENE.instantiate() as ShopItem
		item.kind = SHOP_STOCK[i][0]
		item.price = SHOP_STOCK[i][1]
		item.position = Vector2((i - (slots - 1) * 0.5) * 80.0, -45.0)
		room.add_child(item)


## One chest above the room's middle line. Loot is rolled now (seeded), not
## when it is opened, so a seed always has the same treasure.
func _add_chest(room: Room, rng: RandomNumberGenerator) -> void:
	var chest := CHEST_SCENE.instantiate() as Chest
	var roll := rng.randf()
	if roll < 0.4:
		# A passive item (stays null if every item is already taken).
		chest.item = _roll_item(rng)
	if chest.item != null:
		chest.contents = [[Pickup.Kind.COIN, 5]]
	elif roll < 0.7:
		chest.contents = [[Pickup.Kind.HEART_CONTAINER, 1]]
	else:
		chest.contents = [[Pickup.Kind.BLANK, 1], [Pickup.Kind.AMMO, 1], [Pickup.Kind.COIN, 8]]
	chest.position = Vector2(0.0, -40.0)
	room.add_child(chest)


## Rolls a passive item the player does not own and that is not already placed
## on this floor, so a floor never offers the same item twice.
func _roll_item(rng: RandomNumberGenerator) -> ItemData:
	var exclude: Array = _placed_items.duplicate()
	# Items carried from earlier floors. `Run` is looked up by path (not by its
	# global name) so this script also compiles in headless test scripts.
	var run_node := (Engine.get_main_loop() as SceneTree).root.get_node_or_null("Run")
	if run_node != null:
		exclude.append_array(run_node.snapshot.get("items", []))
	var item := ItemPool.roll(rng, exclude)
	if item != null:
		_placed_items.append(item.id)
	return item


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
		corridor.length = span - from_edge - to_edge
		var along := Vector2.RIGHT if horizontal else Vector2.DOWN
		corridor.position = a.position + along * (from_edge + corridor.length * 0.5)
		# Draw UNDER the rooms: the corridor floor overlaps the doorway and
		# would otherwise paint over the door (later siblings draw on top).
		corridor.z_index = -1
		add_child(corridor)
		corridors.append(corridor)
