extends Node2D
## The HUB: the safe room you return to between runs.
##   * the DUNGEON door starts a new run,
##   * the UNLOCK terminal opens the shop where hub currency buys new guns and
##     items for future runs (see unlocks/ and autoload/save_data.gd).
## It is the game's main scene, so playing starts here.
##
## Everything is built from placeholder shapes in code (walls, floor, the two
## stations): to give the hub real art, replace the Polygon2D floor and the
## HubStation visuals.

## Emitted instead of changing scene when a test drives the hub directly
## (there is no "current scene" then).
signal dungeon_requested

const DUNGEON_SCENE := "res://levels/floor_level/floor_level.tscn"
## Half-size of the room's walkable floor.
const HALF_SIZE := Vector2(260.0, 150.0)
const WALL := 24.0

@onready var player: Player = $Player

var shop: UnlockShop
var _leaving: bool = false


func _ready() -> void:
	# Arriving here means no run is going on (the previous one already ended).
	Run.reset()
	_build_room()
	var door := HubStation.new()
	door.caption = "DUNGEON"
	door.color = Color(0.55, 0.25, 0.65)
	door.position = Vector2(0.0, -HALF_SIZE.y + 36.0)
	door.used.connect(go_to_dungeon)
	add_child(door)
	var terminal := HubStation.new()
	terminal.caption = "UNLOCKS"
	terminal.color = Color(0.25, 0.55, 0.75)
	terminal.position = Vector2(-150.0, 20.0)
	terminal.used.connect(func(): shop.open())
	add_child(terminal)
	shop = UnlockShop.new()
	add_child(shop)
	_build_info_panel()
	player.global_position = Vector2(0.0, 70.0)


## Floor colour + four walls (StaticBody2D on physics layer 1 = "world").
func _build_room() -> void:
	var floor_poly := Polygon2D.new()
	floor_poly.name = "Floor"
	floor_poly.z_index = -10
	floor_poly.color = Color(0.17, 0.16, 0.2)
	floor_poly.polygon = PackedVector2Array([
		-HALF_SIZE, Vector2(HALF_SIZE.x, -HALF_SIZE.y), HALF_SIZE, Vector2(-HALF_SIZE.x, HALF_SIZE.y)])
	add_child(floor_poly)
	var walls := StaticBody2D.new()
	walls.name = "Walls"
	walls.collision_layer = 1
	add_child(walls)
	# [center, size] of the four wall strips around the floor.
	var strips := [
		[Vector2(0.0, -HALF_SIZE.y - WALL * 0.5), Vector2(HALF_SIZE.x * 2.0 + WALL * 2.0, WALL)],
		[Vector2(0.0, HALF_SIZE.y + WALL * 0.5), Vector2(HALF_SIZE.x * 2.0 + WALL * 2.0, WALL)],
		[Vector2(-HALF_SIZE.x - WALL * 0.5, 0.0), Vector2(WALL, HALF_SIZE.y * 2.0)],
		[Vector2(HALF_SIZE.x + WALL * 0.5, 0.0), Vector2(WALL, HALF_SIZE.y * 2.0)],
	]
	for strip in strips:
		var shape := CollisionShape2D.new()
		var rect := RectangleShape2D.new()   # one shape per node: never share them
		rect.size = strip[1]
		shape.shape = rect
		shape.position = strip[0]
		walls.add_child(shape)
		var visual := Polygon2D.new()
		visual.color = Color(0.32, 0.3, 0.38)
		var half: Vector2 = strip[1] * 0.5
		visual.polygon = PackedVector2Array([-half, Vector2(half.x, -half.y), half, Vector2(-half.x, half.y)])
		visual.position = strip[0]
		walls.add_child(visual)


## Corner text: currency, what the last run paid, lifetime stats.
func _build_info_panel() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var label := Label.new()
	label.name = "InfoLabel"
	label.position = Vector2(12.0, 90.0)
	label.add_theme_font_size_override("font_size", 12)
	var text := "HUB\nCurrency: %d" % int(SaveData.get_value("currency", 0))
	if Run.last_reward > 0:
		text += "   (last run paid +%d)" % Run.last_reward
	text += "\nRuns: %d   Wins: %d   Best floor: %d" % [
		SaveData.get_value("runs_played", 0), SaveData.get_value("victories", 0), SaveData.get_value("best_floor", 0)]
	label.text = text
	layer.add_child(label)


## Starts a fresh run and loads its first floor.
func go_to_dungeon() -> void:
	if _leaving:
		return
	_leaving = true
	Run.start_new_run()
	if get_tree().current_scene != null:
		get_tree().change_scene_to_file(DUNGEON_SCENE)
	else:
		dungeon_requested.emit()
