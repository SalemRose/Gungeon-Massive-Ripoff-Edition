class_name BeamEffect
extends Node2D
## The visible laser of a beam gun: a glowing line from the muzzle to wherever
## the beam stops. Visual only; the damage is done by Weapon (hold_beam).
##
## A Weapon creates one lazily next to the player and moves its end points
## every frame. Hidden while the beam is off.
##
## ART: replace the Line2D with an animated sprite stretched along the beam.

var _line: Line2D


func _ready() -> void:
	z_index = 30
	_line = Line2D.new()
	_line.width = 4.0
	_line.begin_cap_mode = Line2D.LINE_CAP_ROUND
	_line.end_cap_mode = Line2D.LINE_CAP_ROUND
	_line.points = PackedVector2Array([Vector2.ZERO, Vector2.ZERO])
	add_child(_line)
	visible = false


## Draws the beam between two world positions.
func show_beam(from: Vector2, to: Vector2, color: Color) -> void:
	_line.default_color = color
	_line.points = PackedVector2Array([to_local(from), to_local(to)])
	_line.width = 3.0 + randf() * 2.0   # flicker
	visible = true


func hide_beam() -> void:
	visible = false
