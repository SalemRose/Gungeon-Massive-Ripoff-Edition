class_name FloorLayout
extends RefCounted
## The generated map of one floor, as pure data (no nodes, no scenes).
##
## It is a grid of cells; each cell is one room. 7b turns the cells into real
## Room nodes and links the doors, so the generator can change (hand-made
## floors, different algorithms) without touching anything else.
##
##     var layout := FloorGenerator.generate(12345, 0)
##     for cell in layout.cells.values():
##         print(cell.grid_pos, " ", FloorLayout.type_name(cell.type))

## Add new types at the END: values may end up in saved data.
enum RoomType { START, COMBAT, SHOP, TREASURE, BOSS }

## Same bit values as Room.Exit, so `cell.exits` can be handed straight to a Room.
const NORTH := 1
const EAST := 2
const SOUTH := 4
const WEST := 8

## Direction bit -> grid step. (y grows downward, like the screen.)
const STEPS := {
	NORTH: Vector2i(0, -1),
	EAST: Vector2i(1, 0),
	SOUTH: Vector2i(0, 1),
	WEST: Vector2i(-1, 0),
}


class Cell extends RefCounted:
	var grid_pos: Vector2i
	var type: int = RoomType.COMBAT
	var exits: int = 0            ## bit flags, see NORTH..WEST
	var distance: int = 0         ## doors to cross from the start room

	func exit_count() -> int:
		var n := 0
		for bit in STEPS:
			if exits & bit:
				n += 1
		return n


var seed_used: int = 0
var floor_index: int = 0
## Vector2i -> Cell
var cells: Dictionary = {}
var start_pos: Vector2i = Vector2i.ZERO
var boss_pos: Vector2i = Vector2i.ZERO


static func type_name(type: int) -> String:
	return RoomType.keys()[type].capitalize()


static func opposite(bit: int) -> int:
	match bit:
		NORTH: return SOUTH
		SOUTH: return NORTH
		EAST: return WEST
		_: return EAST


func get_cell(pos: Vector2i) -> Cell:
	return cells.get(pos)


func cells_of_type(type: int) -> Array:
	return cells.values().filter(func(c): return c.type == type)


## The cell reached by leaving `pos` through `bit`, or null if there is no door.
func neighbor(pos: Vector2i, bit: int) -> Cell:
	var cell: Cell = cells.get(pos)
	if cell == null or not (cell.exits & bit):
		return null
	return cells.get(pos + STEPS[bit])


## Text drawing of the map, for debugging and tests. S start, C combat, $ shop,
## T treasure, B boss; '-' and '|' are doors.
func to_ascii() -> String:
	var min_p := Vector2i(999, 999)
	var max_p := Vector2i(-999, -999)
	for p in cells:
		min_p = Vector2i(mini(min_p.x, p.x), mini(min_p.y, p.y))
		max_p = Vector2i(maxi(max_p.x, p.x), maxi(max_p.y, p.y))
	var letters := ["S", "C", "$", "T", "B"]
	var out := ""
	for y in range(min_p.y, max_p.y + 1):
		var row := ""
		var below := ""
		for x in range(min_p.x, max_p.x + 1):
			var c: Cell = cells.get(Vector2i(x, y))
			row += letters[c.type] if c else " "
			row += "-" if (c and c.exits & EAST) else " "
			below += "|" if (c and c.exits & SOUTH) else " "
			below += " "
		out += row + "\n" + below + "\n"
	return out
