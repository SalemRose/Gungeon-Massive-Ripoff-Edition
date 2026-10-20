extends Node2D
## The real game level: generates a floor from a seed, builds it, and drops
## the player into the start room. Replaces test_level as the main scene.
##
## Debug keys: H hurt, K kill enemies in fighting rooms, N new random floor,
## M toggle the text map in the debug panel.

## 0 = pick a random seed each run.
@export var seed_value: int = 0
@export var floor_index: int = 0

@onready var player: Player = $Player
@onready var debug_label: Label = $DebugLayer/DebugLabel

var builder: FloorBuilder
var room_camera: RoomCamera
var minimap: Minimap
var layout: FloorLayout
var _show_map: bool = true


func _ready() -> void:
	if seed_value == 0:
		seed_value = randi() % 1000000 + 1
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
	minimap.position = Vector2(get_viewport().get_visible_rect().size.x - minimap.size.x - 12.0, 12.0)


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
			seed_value = 0
			get_tree().reload_current_scene()
		KEY_M:
			_show_map = not _show_map


func _on_player_died() -> void:
	await get_tree().create_timer(1.5).timeout
	get_tree().reload_current_scene()
