class_name Corridor
extends Node2D
## A short walled passage joining the doorways of two neighbouring rooms.
##
## The floor builder creates one per door pair. It is only floor + two side
## walls: the doors themselves belong to the rooms at each end, so a corridor
## never locks or fights. Position the node at the MIDDLE of the passage.
##
## ART: the floor is drawn in _draw() and the walls sit under `Visual`, so
## final art can replace both without touching the collision.

const WALL_THICKNESS := 16.0
const WIDTH := 48.0   ## same as Room.DOOR_WIDTH, so the ends line up with the doorways

## Passage length, along the travel direction.
var length: float = 100.0
## true for an east-west passage, false for north-south.
var horizontal: bool = true
var floor_color: Color = Color(0.1, 0.11, 0.14)
var wall_color: Color = Color(0.32, 0.3, 0.38)


func _ready() -> void:
	# Local space: the passage runs along x if horizontal, along y if not.
	# Two wall strips run along its long sides.
	var long := length
	var offset := WIDTH * 0.5 + WALL_THICKNESS * 0.5
	if horizontal:
		_add_wall(Rect2(Vector2(-long * 0.5, -offset - WALL_THICKNESS * 0.5), Vector2(long, WALL_THICKNESS)))
		_add_wall(Rect2(Vector2(-long * 0.5, offset - WALL_THICKNESS * 0.5), Vector2(long, WALL_THICKNESS)))
	else:
		_add_wall(Rect2(Vector2(-offset - WALL_THICKNESS * 0.5, -long * 0.5), Vector2(WALL_THICKNESS, long)))
		_add_wall(Rect2(Vector2(offset - WALL_THICKNESS * 0.5, -long * 0.5), Vector2(WALL_THICKNESS, long)))
	queue_redraw()


func _draw() -> void:
	var floor_size := Vector2(length, WIDTH) if horizontal else Vector2(WIDTH, length)
	draw_rect(Rect2(-floor_size * 0.5, floor_size), floor_color)


func _add_wall(rect: Rect2) -> void:
	var body := StaticBody2D.new()
	body.collision_layer = 1   # "world"
	body.collision_mask = 0
	body.position = rect.get_center()
	var collider := CollisionShape2D.new()
	var shape := RectangleShape2D.new()   # one shape per wall, never shared
	shape.size = rect.size
	collider.shape = shape
	body.add_child(collider)
	var art := Node2D.new()
	art.name = "Visual"
	var polygon := Polygon2D.new()
	polygon.color = wall_color
	var half := rect.size * 0.5
	polygon.polygon = PackedVector2Array([-half, Vector2(half.x, -half.y), half, Vector2(-half.x, half.y)])
	art.add_child(polygon)
	body.add_child(art)
	add_child(body)
