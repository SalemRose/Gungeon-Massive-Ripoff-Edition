class_name TrainingDummy
extends StaticBody2D
## A punching bag for testing guns. Shows each hit as a floating number and
## refills itself when "killed". Real enemies will get their own scripts; this
## one exists to show the minimum a shootable thing needs: a collision body on
## the enemy layer and a take_damage(amount) -> bool method.

@export var max_health: float = 100.0

var health: float
var total_damage_taken: float = 0.0

@onready var visual: Node2D = $Visual
@onready var health_label: Label = $HealthLabel


func _ready() -> void:
	health = max_health
	_refresh_label()


## Called by Bullet. Returns true when the hit landed.
func take_damage(amount: float) -> bool:
	health -= amount
	total_damage_taken += amount
	_flash()
	FloatingText.spawn(get_parent(), global_position + Vector2(0.0, -34.0), ("%.1f" % amount).trim_suffix(".0"))
	if health <= 0.0:
		health = max_health  # training dummies are immortal
	_refresh_label()
	return true


func _refresh_label() -> void:
	health_label.text = "%d" % ceili(health)


func _flash() -> void:
	visual.modulate = Color(3.0, 3.0, 3.0)  # over-bright = flash white
	var tween := create_tween()
	tween.tween_property(visual, "modulate", Color.WHITE, 0.1)
