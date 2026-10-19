class_name Door
extends StaticBody2D
## A door filling one gap in a room wall. Open = you walk through it,
## closed = a solid wall that blocks the player, enemies, AND bullets (it sits
## on the "world" physics layer) and line of sight.
##
## Doors are created and driven by Room; you rarely touch them directly:
##     door.close()   asks the door to close
##     door.open()    opens it
##
## NEVER CRUSHES ANYONE: close() only takes effect once nothing stands in the
## doorway. Until then the door waits and keeps checking every physics frame.
##
## ART: everything visible is under `Visual`. Replace the Slab polygon with a
## sprite or animation later. This script only toggles Visual's visibility,
## alpha and scale.

signal opened
signal closed

const FADE_TIME := 0.2
## Layers that must be clear before the door can close: player (2) + enemy (4).
const BLOCKER_MASK := 2 | 4
## The doorway check reaches this far past the door on both sides.
const CLEARANCE_MARGIN := 6.0

## True once the door is actually solid (not merely asked to close).
var is_closed: bool = false

var _close_requested: bool = false
var _size: Vector2 = Vector2(48.0, 16.0)
var _tween: Tween

@onready var shape: CollisionShape2D = $CollisionShape2D
@onready var visual: Node2D = $Visual
@onready var slab: Polygon2D = $Visual/Slab
@onready var clearance: Area2D = $Clearance
@onready var clearance_shape: CollisionShape2D = $Clearance/CollisionShape2D


func _ready() -> void:
	_apply_size()
	shape.disabled = true  # starts open
	visual.visible = false


## Sets the door's size (width x thickness of the gap it fills). Call after the
## door has been added to the tree. Shapes are created fresh for every door, so
## doors never share (and accidentally resize) each other's collision shape.
func setup(size: Vector2) -> void:
	_size = size
	if is_node_ready():
		_apply_size()


func close() -> void:
	_close_requested = true


func open() -> void:
	_close_requested = false
	if not is_closed:
		return
	is_closed = false
	shape.set_deferred("disabled", true)
	_animate(false)
	opened.emit()


func _physics_process(_delta: float) -> void:
	if not _close_requested or is_closed:
		return
	# Wait until the doorway is empty, then shut.
	if clearance.get_overlapping_bodies().is_empty():
		_close_requested = false
		is_closed = true
		shape.set_deferred("disabled", false)
		_animate(true)
		closed.emit()


func _apply_size() -> void:
	var door_shape := RectangleShape2D.new()
	door_shape.size = _size
	shape.shape = door_shape

	var clear_shape := RectangleShape2D.new()
	clear_shape.size = _size + Vector2.ONE * CLEARANCE_MARGIN * 2.0
	clearance_shape.shape = clear_shape

	var half := _size * 0.5
	slab.polygon = PackedVector2Array([-half, Vector2(half.x, -half.y), half, Vector2(-half.x, half.y)])


## The door grows/shrinks along its long side while fading.
func _animate(closing: bool) -> void:
	if _tween:
		_tween.kill()
	var along_x := _size.x >= _size.y
	var small := Vector2(0.15, 1.0) if along_x else Vector2(1.0, 0.15)

	_tween = create_tween().set_parallel(true)
	if closing:
		visual.visible = true
		visual.scale = small
		visual.modulate.a = 0.0
		_tween.tween_property(visual, "scale", Vector2.ONE, FADE_TIME)
		_tween.tween_property(visual, "modulate:a", 1.0, FADE_TIME)
	else:
		_tween.tween_property(visual, "scale", small, FADE_TIME)
		_tween.tween_property(visual, "modulate:a", 0.0, FADE_TIME)
		_tween.chain().tween_callback(func(): visual.visible = false)
