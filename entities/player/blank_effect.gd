class_name BlankEffect
extends Node2D
## The blank: a shockwave that wipes enemy bullets and shoves enemies back.
##
## Call it from anywhere (the player, a pickup, a boss phase):
##     BlankEffect.fire(level_node, world_position, 420.0, 320.0)
## It does the gameplay part immediately and spawns a short expanding ring that
## frees itself. The caller does NOT need to keep a reference.
##
## WHAT IT AFFECTS
##   - every HOSTILE bullet (one that can hit the player) inside the radius is
##     destroyed. The player's own bullets are never touched.
##   - every awake, moving enemy inside the radius is pushed away. The push is
##     weaker at the edge of the radius. Turrets and enemies that are still
##     spawning don't budge.
##
## ART: the ring is drawn in code in _draw(). Replace it with a sprite or an
## animated effect later; the gameplay lives only in fire().

const DURATION := 0.35
const RING_COLOR := Color(0.6, 0.9, 1.0)

var _max_radius: float = 100.0
var _progress: float = 0.0


## Triggers a blank. `parent` is the node the ring is added to (the level).
static func fire(parent: Node, world_position: Vector2, radius: float, knockback: float) -> void:
	var tree := parent.get_tree()

	for node in tree.get_nodes_in_group("bullets"):
		var bullet := node as Bullet
		if bullet and bullet.is_hostile() and bullet.global_position.distance_to(world_position) <= radius:
			bullet.destroy()

	for node in tree.get_nodes_in_group("enemies"):
		var enemy := node as Enemy
		if enemy == null:
			continue
		var offset := enemy.global_position - world_position
		var distance := offset.length()
		if distance > radius:
			continue
		# Straight up from the player if the enemy is on top of us.
		var direction := offset / distance if distance > 0.001 else Vector2.UP
		enemy.apply_knockback(direction, knockback * lerpf(1.0, 0.4, distance / radius))

	var effect := BlankEffect.new()
	effect._max_radius = radius
	effect.z_index = 50
	parent.add_child(effect)
	effect.global_position = world_position
	var tween := effect.create_tween()
	tween.tween_property(effect, "_progress", 1.0, DURATION)
	tween.tween_callback(effect.queue_free)


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	var radius := _max_radius * ease(_progress, 0.4)
	var color := RING_COLOR
	color.a = 1.0 - _progress
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 96, color, 3.0, true)
	var fill := RING_COLOR
	fill.a = 0.12 * (1.0 - _progress)
	draw_circle(Vector2.ZERO, radius, fill)
