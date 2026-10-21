class_name OrbitOrb
extends Node2D
## One orb of the Orbit gun. It circles the player for a few seconds, hurting
## enemies it touches and swatting enemy bullets out of the air, then fades.
##
## The orb itself is "dumb": the Weapon that owns it decides WHERE it is each
## frame (so several orbs stay evenly spread). The orb only does the fighting:
##
##     var orb := OrbitOrb.new()
##     orb.damage = 6.0
##     orb.lifetime = 7.0
##     level.add_child(orb)
##
## ART: everything visible is under `Visual`, built in _build_visual().
## Replace it with a sprite and nothing else changes.

signal expired

@export var damage: float = 6.0
@export var lifetime: float = 7.0
@export var color: Color = Color(0.6, 0.6, 1.0)
## Seconds before the same enemy can be hurt by this orb again.
@export var rehit_time: float = 0.35
## Contact distances (pixels, center to center).
const ENEMY_REACH := 16.0
const BULLET_REACH := 12.0

var _age: float = 0.0
## Instance id of an enemy -> seconds until it can be hit again.
var _cooldowns: Dictionary = {}

@onready var visual: Node2D = $Visual if has_node("Visual") else null


func _ready() -> void:
	add_to_group("orbit_orbs")
	z_index = 20
	_build_visual()


func _physics_process(delta: float) -> void:
	_age += delta
	if _age >= lifetime:
		expire()
		return
	# Blink during the last second so the player sees it running out.
	if visual != null:
		visual.visible = (lifetime - _age) > 1.0 or int(_age * 10.0) % 2 == 0
		visual.rotation += delta * 8.0

	for key in _cooldowns.keys():
		_cooldowns[key] -= delta
		if _cooldowns[key] <= 0.0:
			_cooldowns.erase(key)

	# Hurt enemies we touch.
	for node in get_tree().get_nodes_in_group("enemies"):
		var enemy := node as Node2D
		if enemy == null or _cooldowns.has(enemy.get_instance_id()):
			continue
		if not (enemy.has_method("can_be_targeted") and enemy.can_be_targeted()):
			continue
		if global_position.distance_to(enemy.global_position) <= ENEMY_REACH:
			if enemy.take_damage(damage):
				_cooldowns[enemy.get_instance_id()] = rehit_time

	# Swat enemy bullets.
	for node in get_tree().get_nodes_in_group("bullets"):
		var bullet := node as Bullet
		if bullet != null and bullet.is_hostile() and global_position.distance_to(bullet.global_position) <= BULLET_REACH:
			bullet.destroy()


## Removes the orb (time ran out, or the gun replaced it with a newer one).
func expire() -> void:
	if is_queued_for_deletion():
		return
	set_physics_process(false)
	remove_from_group("orbit_orbs")
	expired.emit()
	var tween := create_tween()
	tween.tween_property(self, "scale", Vector2.ZERO, 0.12)
	tween.tween_callback(queue_free)


## PLACEHOLDER art: a glowing disc with a darker core.
func _build_visual() -> void:
	if visual == null:
		visual = Node2D.new()
		visual.name = "Visual"
		add_child(visual)
	var outer := Polygon2D.new()
	outer.color = color
	var core := Polygon2D.new()
	core.color = color.lightened(0.6)
	var o := PackedVector2Array()
	var c := PackedVector2Array()
	for i in 10:
		o.append(Vector2.from_angle(TAU * i / 10.0) * 7.0)
		c.append(Vector2.from_angle(TAU * i / 10.0) * 3.5)
	outer.polygon = o
	core.polygon = c
	visual.add_child(outer)
	visual.add_child(core)
