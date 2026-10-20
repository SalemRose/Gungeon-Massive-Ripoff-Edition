class_name Minimap
extends Control
## Corner minimap, drawn in code (placeholder look; swap _draw for icons later).
##
## What it shows (like Gungeon):
##   - rooms you have visited, in their type color
##   - rooms next to a visited one that you have not entered yet, dimmed
##     (special rooms keep their color so you can spot the shop / boss)
##   - the doorways between known rooms
##   - your current room, outlined; the map scrolls to keep it in the middle
##
## It reads the FloorLayout for the shape and a RoomCamera's `room_changed`
## signal to know where you are, so it needs no other wiring:
##
##     var map := Minimap.new()
##     hud_layer.add_child(map)
##     map.setup(layout, room_camera)

const CELL := 14.0
const GAP := 5.0
const TYPE_COLORS := {
	FloorLayout.RoomType.START: Color(0.45, 0.75, 0.9),
	FloorLayout.RoomType.COMBAT: Color(0.62, 0.62, 0.7),
	FloorLayout.RoomType.SHOP: Color(0.95, 0.8, 0.3),
	FloorLayout.RoomType.TREASURE: Color(0.75, 0.5, 0.95),
	FloorLayout.RoomType.BOSS: Color(0.9, 0.3, 0.3),
}

var layout: FloorLayout
var current_pos: Vector2i = Vector2i.ZERO
## Vector2i -> true for every room the player has entered.
var visited: Dictionary = {}


func setup(new_layout: FloorLayout, room_camera: RoomCamera) -> void:
	layout = new_layout
	custom_minimum_size = Vector2(150, 120)
	size = custom_minimum_size
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_enter(layout.start_pos)
	room_camera.room_changed.connect(_on_room_changed)


func is_visited(pos: Vector2i) -> bool:
	return visited.has(pos)


## Visited, or one door away from a visited room.
func is_known(pos: Vector2i) -> bool:
	if visited.has(pos):
		return true
	for bit in FloorLayout.STEPS:
		var next: Vector2i = pos + FloorLayout.STEPS[bit]
		if visited.has(next) and layout.neighbor(next, FloorLayout.opposite(bit)) != null:
			return true
	return false


func _on_room_changed(room: Room) -> void:
	# null = in a corridor: keep showing the last room.
	if room != null and room.has_meta("grid_pos"):
		_enter(room.get_meta("grid_pos"))


func _enter(pos: Vector2i) -> void:
	current_pos = pos
	visited[pos] = true
	queue_redraw()


func _draw() -> void:
	if layout == null:
		return
	draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, 0.45))
	var pitch := CELL + GAP
	var origin := size * 0.5 - Vector2(CELL, CELL) * 0.5   # where current_pos is drawn
	for pos in layout.cells:
		if not is_known(pos):
			continue
		var cell: FloorLayout.Cell = layout.cells[pos]
		var top_left := origin + Vector2(pos - current_pos) * pitch
		# Doorways to the east/south, only toward known rooms.
		for bit in [FloorLayout.EAST, FloorLayout.SOUTH]:
			var other := layout.neighbor(pos, bit)
			if other != null and is_known(other.grid_pos):
				var step := Vector2(FloorLayout.STEPS[bit])
				draw_line(top_left + Vector2(CELL, CELL) * 0.5, top_left + Vector2(CELL, CELL) * 0.5 + step * pitch, Color(0.8, 0.8, 0.85, 0.7), 2.0)
		var color: Color = TYPE_COLORS[cell.type]
		if not visited.has(pos):
			# Unvisited: dim, but special rooms stay recognisable.
			color = color.darkened(0.55) if cell.type != FloorLayout.RoomType.COMBAT else Color(0.3, 0.3, 0.36)
		draw_rect(Rect2(top_left, Vector2(CELL, CELL)), color)
		if pos == current_pos:
			draw_rect(Rect2(top_left - Vector2.ONE * 2.0, Vector2(CELL, CELL) + Vector2.ONE * 4.0), Color.WHITE, false, 2.0)
