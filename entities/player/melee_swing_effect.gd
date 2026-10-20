class_name MeleeSwingEffect
extends Node2D
## The visible slash of the melee swing: a wedge that fades out. Visual only;
## the damage is dealt by Player._melee_hit().
##
##     MeleeSwingEffect.play(player, 38.0, 130.0, 0.25)
##
## It is added as a child of the player so it follows them, points where the
## swing was aimed, and removes itself when done.
##
## ART: replace _draw() with a sprite/animation. Nothing else depends on it.

const COLOR := Color(1.0, 0.95, 0.75)

var _range: float = 40.0
var _arc: float = deg_to_rad(120.0)
var _progress: float = 0.0


static func play(player: Node2D, reach: float, arc_degrees: float, duration: float, direction: Vector2) -> void:
	var effect := MeleeSwingEffect.new()
	effect._range = reach
	effect._arc = deg_to_rad(arc_degrees)
	effect.rotation = direction.angle()
	effect.z_index = 40
	player.add_child(effect)
	var tween := effect.create_tween()
	tween.tween_property(effect, "_progress", 1.0, duration)
	tween.tween_callback(effect.queue_free)


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	# The slash sweeps across the arc and fades.
	var sweep := clampf(_progress * 2.2, 0.0, 1.0)
	var start := -_arc * 0.5
	var end := start + _arc * sweep
	var color := COLOR
	color.a = 0.85 * (1.0 - _progress)
	draw_arc(Vector2.ZERO, _range, start, end, 24, color, 5.0, true)
	var fill := COLOR
	fill.a = 0.18 * (1.0 - _progress)
	var points := PackedVector2Array([Vector2.ZERO])
	for i in 13:
		points.append(Vector2.from_angle(lerpf(start, end, float(i) / 12.0)) * _range)
	if sweep > 0.05:
		draw_colored_polygon(points, fill)
