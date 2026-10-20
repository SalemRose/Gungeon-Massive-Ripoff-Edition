class_name BossBar
extends Control
## Big health bar with the boss's name, at the bottom of the screen. It shows
## while a boss is awake and alive and hides otherwise. It finds the boss
## through the "bosses" group, so nothing has to be connected:
##
##     var bar := BossBar.new()
##     hud_layer.add_child(bar)
##
## ART: replace the ProgressBar/Label built in _ready() with a styled scene.

var _bar: ProgressBar
var _label: Label


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	custom_minimum_size = Vector2(520, 44)
	size = custom_minimum_size
	position = Vector2((1280.0 - size.x) * 0.5, 720.0 - 64.0)
	_label = Label.new()
	_label.size = Vector2(size.x, 20)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.add_theme_font_size_override("font_size", 14)
	add_child(_label)
	_bar = ProgressBar.new()
	_bar.position = Vector2(0, 22)
	_bar.size = Vector2(size.x, 14)
	_bar.show_percentage = false
	_bar.add_theme_stylebox_override("fill", _flat(Color(0.8, 0.2, 0.25)))
	_bar.add_theme_stylebox_override("background", _flat(Color(0.12, 0.05, 0.06)))
	add_child(_bar)
	visible = false


func _process(_delta: float) -> void:
	var boss := _find_boss()
	visible = boss != null
	if boss == null:
		return
	_label.text = boss.boss_name
	_bar.max_value = boss.max_health
	_bar.value = maxf(boss.health, 0.0)


## The first awake, living boss, or null.
func _find_boss() -> Boss:
	for node in get_tree().get_nodes_in_group("bosses"):
		var boss := node as Boss
		if boss != null and boss.state != Enemy.State.DORMANT and boss.state != Enemy.State.DEAD:
			return boss
	return null


func _flat(color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	return style
