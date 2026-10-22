extends Node2D
## The real game level: generates a floor from a seed, builds it, and drops
## the player into the start room. Replaces test_level as the main scene.
##
## Debug keys: H hurt, K kill enemies in fighting rooms, N new random floor,
## M toggle the text map in the debug panel.

## 0 (normal play) = follow the current run (autoload `Run`: its seed and floor).
## Any other value = a fixed debug/test floor that ignores the run.
@export var seed_value: int = 0
@export var floor_index: int = 0
## Seconds of fade when changing floor (0 = instant, used by tests).
@export var fade_time: float = 0.4

## Emitted instead of reloading the scene when there is no current scene
## (only happens when a test drives the level directly).
signal reload_requested

const HUB_SCENE := "res://levels/hub/hub.tscn"

@onready var player: Player = $Player
@onready var debug_label: Label = $DebugLayer/DebugLabel

var builder: FloorBuilder
var room_camera: RoomCamera
var minimap: Minimap
var layout: FloorLayout
var stairs: Stairs
var _show_map: bool = true
var _uses_run: bool = false
var _fade: ColorRect
var _floor_label: Label
var _leaving: bool = false


func _ready() -> void:
	_uses_run = seed_value == 0
	if _uses_run:
		if not Run.active:
			Run.start_new_run()
		seed_value = Run.run_seed
		floor_index = Run.floor_index
	layout = FloorGenerator.generate(seed_value, floor_index)
	builder = FloorBuilder.new()
	builder.name = "Floor"
	add_child(builder)
	# Draw order follows tree order: the floor must come BEFORE the player or
	# the room floors are painted on top of the player and hide them.
	move_child(builder, 0)
	builder.build(layout)
	# Place the player at the start room's center (it is already in the tree).
	player.global_position = builder.start_room().global_position
	player.died.connect(_on_player_died)
	if _uses_run:
		Run.apply(player)   # what you carried down from the last floor
	# Holds the camera inside the current room (see room_camera.gd).
	room_camera = RoomCamera.new()
	add_child(room_camera)
	room_camera.setup(player)
	# Minimap in the top-right corner, on its own canvas layer.
	var map_layer := CanvasLayer.new()
	add_child(map_layer)
	minimap = Minimap.new()
	map_layer.add_child(minimap)
	minimap.setup(layout, room_camera)
	map_layer.add_child(BossBar.new())   # shows itself while a boss is fighting
	minimap.position = Vector2(get_viewport().get_visible_rect().size.x - minimap.size.x - 12.0, 12.0)
	_floor_label = Label.new()
	_floor_label.text = "Floor %d / %d" % [floor_index + 1, Run.FLOORS_PER_RUN]
	_floor_label.add_theme_font_size_override("font_size", 13)
	_floor_label.position = minimap.position + Vector2(0.0, minimap.size.y + 2.0)
	map_layer.add_child(_floor_label)
	# Black sheet used to fade between floors.
	var fade_layer := CanvasLayer.new()
	fade_layer.layer = 100
	add_child(fade_layer)
	_fade = ColorRect.new()
	_fade.color = Color.BLACK
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	fade_layer.add_child(_fade)
	if fade_time > 0.0:
		create_tween().tween_property(_fade, "color:a", 0.0, fade_time)   # fade in
	else:
		_fade.color.a = 0.0
	# When the boss dies and the room opens, the way down appears.
	builder.boss_room().cleared.connect(_spawn_stairs)


func _process(_delta: float) -> void:
	var lines: PackedStringArray = [
		player.debug_text(),
		"fps: %d   seed: %d   floor: %d   rooms: %d" % [Engine.get_frames_per_second(), seed_value, floor_index, layout.cells.size()],
		"H hurt   K kill enemies   N new floor   M map",
		"",
	]
	if _show_map:
		lines.append(layout.to_ascii())
	debug_label.text = "\n".join(lines)


func _unhandled_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	match key.physical_keycode:
		KEY_H:
			player.take_damage(1)
		KEY_K:
			for room in get_tree().get_nodes_in_group("rooms"):
				for enemy in (room as Room).get_enemies():
					enemy.take_damage(99999.0)
		KEY_N:
			Run.reset()
			seed_value = 0
			_reload()
		KEY_M:
			_show_map = not _show_map


## The way down, in the middle of the boss room.
func _spawn_stairs() -> void:
	if stairs != null:
		return
	stairs = load("res://levels/props/stairs.tscn").instantiate() as Stairs
	stairs.caption = "VICTORY" if Run.is_last_floor() else "DOWN"
	stairs.position = Vector2.ZERO   # the boss room's center
	builder.boss_room().add_child(stairs)
	stairs.used.connect(descend)


## Leaves the floor: next floor of the run, or the end of the run on the last.
func descend() -> void:
	if _leaving:
		return
	_leaving = true
	if Run.is_last_floor():
		FloatingText.spawn(self, player.global_position + Vector2(0.0, -30.0), "RUN COMPLETE!", Color(1.0, 0.9, 0.4), 16)
		Run.end_run(true, player)   # pays the run reward into the save
	else:
		Run.advance(player)
	if fade_time > 0.0:
		var tween := create_tween()
		tween.tween_property(_fade, "color:a", 1.0, fade_time)
		await tween.finished
	if _uses_run and not Run.active:
		_go_to_hub()   # the run is over
	else:
		_reload()


func _on_player_died() -> void:
	await get_tree().create_timer(1.5).timeout
	Run.end_run(false, player)   # dying ends the run (recorded in the save)
	if _uses_run:
		_go_to_hub()
	else:
		_reload()


## After a run ends (victory or death) the player returns to the hub. Like
## _reload(), it only emits `reload_requested` when a test drives the level.
func _go_to_hub() -> void:
	if get_tree().current_scene != null:
		get_tree().change_scene_to_file(HUB_SCENE)
	else:
		reload_requested.emit()


func _reload() -> void:
	if get_tree().current_scene != null:
		get_tree().reload_current_scene()
	else:
		reload_requested.emit()
