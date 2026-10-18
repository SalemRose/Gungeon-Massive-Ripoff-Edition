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
	_spawn_damage_number(amount)
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


func _spawn_damage_number(amount: float) -> void:
	var label := Label.new()
	label.text = ("%.1f" % amount).trim_suffix(".0")
	label.position = Vector2(randf_range(-14.0, 6.0), -34.0)
	label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	label.add_theme_font_size_override("font_size", 10)
	add_child(label)
	var tween := create_tween().set_parallel(true)
	tween.tween_property(label, "position:y", label.position.y - 22.0, 0.6)
	tween.tween_property(label, "modulate:a", 0.0, 0.6)
	tween.chain().tween_callback(label.queue_free)
