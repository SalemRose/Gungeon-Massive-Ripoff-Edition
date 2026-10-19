class_name FloatingText
extends RefCounted
## Little text that drifts up and fades: damage numbers, "+5", "RELOAD"...
## Use it without creating anything:
##     FloatingText.spawn(get_parent(), global_position, "12")
## Add it to the LEVEL (get_parent()), not to the thing that was hit, so the
## text survives when that thing dies.

static func spawn(
	parent: Node,
	world_position: Vector2,
	text: String,
	color: Color = Color(1.0, 0.85, 0.3),
	font_size: int = 10,
) -> void:
	var label := Label.new()
	label.text = text
	label.z_index = 100
	label.add_theme_color_override("font_color", color)
	label.add_theme_font_size_override("font_size", font_size)
	parent.add_child(label)
	label.global_position = world_position + Vector2(randf_range(-14.0, 6.0), 0.0)

	var tween := label.create_tween().set_parallel(true)
	tween.tween_property(label, "position:y", label.position.y - 22.0, 0.6)
	tween.tween_property(label, "modulate:a", 0.0, 0.6)
	tween.chain().tween_callback(label.queue_free)
