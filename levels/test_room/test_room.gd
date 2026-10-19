extends Node2D
## Throwaway sandbox for testing the player. Real rooms come with the floor
## generator; nothing here needs to be kept.
##
## Test keys (only in this scene):
##   H  = hurt the player by 1 (try pressing it right after a roll starts to
##        see the invincibility frames block it)
##   N  = clear and respawn the four test enemies

## Half of the playable area; matches the wall positions in test_room.tscn.
const ROOM_HALF_SIZE := Vector2(400, 250)
const GRID_STEP := 50

## Which enemies appear and where. Add a line (and a new enemy scene) to test more.
const ENEMY_SPAWNS: Array[Dictionary] = [
	{"scene": preload("res://entities/enemies/bullet_kin.tscn"), "position": Vector2(-60, -170)},
	{"scene": preload("res://entities/enemies/shotgun_kin.tscn"), "position": Vector2(-60, 170)},
	{"scene": preload("res://entities/enemies/ring_turret.tscn"), "position": Vector2(60, 0)},
	{"scene": preload("res://entities/enemies/spiral_mage.tscn"), "position": Vector2(220, -170)},
]

@onready var player: Player = $Player
@onready var enemies: Node2D = $Enemies
@onready var debug_label: Label = $DebugLayer/DebugLabel


func _ready() -> void:
	player.died.connect(_on_player_died)
	_spawn_enemies()


func _process(_delta: float) -> void:
	debug_label.text = "%s\nfps: %d\n\nWASD/left stick: move   Mouse/right stick: aim\nLMB/RT: shoot   R/X: reload   Wheel/D-pad: swap gun\nSpace/RMB/A: roll   H: hurt (debug)   N: respawn enemies" % [
		player.debug_text(),
		Engine.get_frames_per_second(),
	]


func _unhandled_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key and key.pressed and not key.echo:
		if key.physical_keycode == KEY_H:
			var landed := player.take_damage(1)
			print("hurt test -> ", "hit" if landed else "blocked by invincibility")
		elif key.physical_keycode == KEY_N:
			_spawn_enemies()


## Replaces whatever enemies are left with a fresh set.
func _spawn_enemies() -> void:
	for old in enemies.get_children():
		old.queue_free()
	for spawn in ENEMY_SPAWNS:
		var enemy := (spawn["scene"] as PackedScene).instantiate() as Enemy
		enemies.add_child(enemy)
		enemy.global_position = spawn["position"]


## Draws the floor and a grid so movement is easy to see. Parents draw before
## their children, so walls and the player appear on top.
func _draw() -> void:
	draw_rect(Rect2(-ROOM_HALF_SIZE, ROOM_HALF_SIZE * 2.0), Color(0.13, 0.14, 0.18))
	for x in range(-int(ROOM_HALF_SIZE.x), int(ROOM_HALF_SIZE.x) + 1, GRID_STEP):
		draw_line(Vector2(x, -ROOM_HALF_SIZE.y), Vector2(x, ROOM_HALF_SIZE.y), Color(1, 1, 1, 0.05))
	for y in range(-int(ROOM_HALF_SIZE.y), int(ROOM_HALF_SIZE.y) + 1, GRID_STEP):
		draw_line(Vector2(-ROOM_HALF_SIZE.x, y), Vector2(ROOM_HALF_SIZE.x, y), Color(1, 1, 1, 0.05))


func _on_player_died() -> void:
	await get_tree().create_timer(1.5).timeout
	get_tree().reload_current_scene()
