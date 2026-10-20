class_name RoomCamera
extends Node
## Gungeon-style room camera: inside a room the view is held within that room's
## walls (and a room smaller than the screen sits centered), in corridors the
## camera is free and follows the player, and the change between the two is
## eased by the camera's own limit/position smoothing.
##
##     var cam := RoomCamera.new()
##     add_child(cam)
##     cam.setup(player)
##     cam.room_changed.connect(func(room): print("now in ", room.name))
##
## It only drives the limits of the player's existing Camera2D, so the lean
## and shake in player.gd keep working untouched.

## The room the player stands in changed. `room` is null in corridors.
signal room_changed(room: Room)

## Camera limits for "no limit" (Godot's own defaults).
const FREE_LIMIT := 10000000

var current_room: Room
var _player: Player


func setup(player: Player) -> void:
	_player = player
	player.camera.limit_smoothed = true
	# Camera limits don't see the aim "lean" offset, so ask us to trim it.
	player.camera_lean_limiter = _limit_lean
	_apply(null)


func _process(_delta: float) -> void:
	if _player == null:
		return
	var room := _room_at(_player.global_position)
	if room != current_room:
		current_room = room
		_apply(room)
		room_changed.emit(room)


## The room whose floor contains `point`, or null (corridor / doorway / void).
func _room_at(point: Vector2) -> Room:
	for node in get_tree().get_nodes_in_group("rooms"):
		var room := node as Room
		if Rect2(room.global_position - room.size * 0.5, room.size).has_point(point):
			return room
	return null


## Holds the camera inside `room` (walls included), or frees it for null.
func _apply(room: Room) -> void:
	var camera := _player.camera
	if room == null:
		camera.limit_left = -FREE_LIMIT
		camera.limit_top = -FREE_LIMIT
		camera.limit_right = FREE_LIMIT
		camera.limit_bottom = FREE_LIMIT
		return
	var view := Rect2(room.global_position - room.size * 0.5, room.size).grow(Room.WALL_THICKNESS)
	camera.limit_left = int(view.position.x)
	camera.limit_top = int(view.position.y)
	camera.limit_right = int(view.end.x)
	camera.limit_bottom = int(view.end.y)


## Trims the camera's aim-lean so the view never leaves the room: along an
## axis where the room is smaller than the screen the lean is cancelled (the
## camera stays centered), otherwise the view may go up to the walls.
func _limit_lean(lean: Vector2) -> Vector2:
	if current_room == null:
		return lean
	var camera := _player.camera
	var base := camera.get_screen_center_position() - camera.offset
	var half_view := camera.get_viewport_rect().size / camera.zoom * 0.5
	var walls := Rect2(current_room.global_position - current_room.size * 0.5, current_room.size).grow(Room.WALL_THICKNESS)
	var target := base + lean
	for axis in 2:
		var low := walls.position[axis] + half_view[axis]
		var high := walls.end[axis] - half_view[axis]
		if low >= high:
			target[axis] = base[axis]   # room smaller than the screen: stay put
		else:
			target[axis] = clampf(target[axis], low, high)
	return target - base
