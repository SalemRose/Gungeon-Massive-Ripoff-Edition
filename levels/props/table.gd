class_name Table
extends StaticBody2D
## A table you can flip into cover, Gungeon style.
##
##   STANDING   a low obstacle: blocks walking (you, enemies) but bullets fly
##              over it. Walk up to it and press Interact (E / gamepad Y).
##   FLIPPED    turned on its side: a thin barrier that STOPS ENEMY BULLETS
##              (taking damage until it breaks) while YOUR bullets pass through,
##              so you can shoot from behind it.
##
## The barrier faces the player who flipped it: stand south of the table and it
## becomes a horizontal wall between you and whatever is north of it.
##
## PHYSICS LAYERS (Project Settings > Layer Names)
##   8 "table"  everything solid here blocks walking (player and enemies check it)
##   9 "cover"  only a flipped table is here; only enemy bullets check it
##
## INTERACTION: tables join the "interactables" group and provide
## can_interact(player), interact(player) and get_prompt(). The player presses
## Interact near the closest one. Shops, chests and stairs will do the same.
##
## ART: everything visible is under `Visual`. Replace the Top polygon with
## sprites for the standing and flipped look; this script only recolours Top.

signal flipped
signal broken

const TABLE_LAYER := 128   # layer 8
const COVER_LAYER := 256   # layer 9
const PROMPT_RANGE := 44.0

@export var standing_size: Vector2 = Vector2(48.0, 24.0)
## Size of the barrier when its long side is horizontal (it is rotated for
## east/west flips).
@export var flipped_size: Vector2 = Vector2(48.0, 10.0)
@export var max_health: float = 30.0
@export var standing_color: Color = Color(0.58, 0.40, 0.24)
@export var flipped_color: Color = Color(0.38, 0.26, 0.16)

var is_flipped: bool = false
var health: float = 0.0

var _tween: Tween
var _player: Player

@onready var shape: CollisionShape2D = $CollisionShape2D
@onready var visual: Node2D = $Visual
@onready var top: Polygon2D = $Visual/Top
@onready var prompt: Label = $Prompt


func _ready() -> void:
	add_to_group("interactables")
	health = max_health
	collision_layer = TABLE_LAYER
	collision_mask = 0
	_apply_size(standing_size)
	top.color = standing_color


func _process(_delta: float) -> void:
	# Show the "press E" hint only while a player who could flip us is close.
	if not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player") as Player
	var near := _player != null and can_interact(_player) and global_position.distance_to(_player.global_position) <= PROMPT_RANGE
	prompt.visible = near
	if near:
		prompt.text = get_prompt(_player)


# --- Interaction (called by the player) ---------------------------------------

func can_interact(_player_node: Player) -> bool:
	return not is_flipped


func get_prompt(player_node: Player) -> String:
	return "Y" if player_node.using_gamepad else "E"


func interact(player_node: Player) -> void:
	flip(player_node.global_position)


# --- Flipping ---------------------------------------------------------------------

## Flips the table so the barrier stands between `from_position` and the table.
func flip(from_position: Vector2) -> void:
	if is_flipped:
		return
	is_flipped = true
	var away := global_position - from_position
	# Pushed mostly east/west -> the barrier runs north/south, and vice versa.
	var size := flipped_size
	if absf(away.x) > absf(away.y):
		size = Vector2(flipped_size.y, flipped_size.x)
	_apply_size(size)
	collision_layer = TABLE_LAYER | COVER_LAYER

	top.color = flipped_color
	if _tween:
		_tween.kill()
	visual.scale = Vector2(1.25, 1.25)
	_tween = create_tween()
	_tween.tween_property(visual, "scale", Vector2.ONE, 0.18)
	flipped.emit()


# --- Taking hits (called by bullets) ------------------------------------------------

## Only a flipped table is ever on the layer enemy bullets check, so a standing
## table is never asked. Returns true when the hit landed (the bullet stops).
func take_damage(amount: float) -> bool:
	if not is_flipped:
		return false
	health -= amount
	_flash()
	if health <= 0.0:
		_break()
	return true


func _flash() -> void:
	top.modulate = Color(2.2, 2.2, 2.2)
	var flash := create_tween()
	flash.tween_property(top, "modulate", Color.WHITE, 0.08)


func _break() -> void:
	collision_layer = 0  # stops blocking right away
	broken.emit()
	var tween := create_tween().set_parallel(true)
	tween.tween_property(visual, "scale", Vector2(1.4, 0.2), 0.15)
	tween.tween_property(visual, "modulate:a", 0.0, 0.15)
	tween.chain().tween_callback(queue_free)


# --- Helpers ---------------------------------------------------------------------------

## Every table gets its own shape resource, so resizing one never resizes another.
func _apply_size(size: Vector2) -> void:
	var rect := RectangleShape2D.new()
	rect.size = size
	shape.shape = rect
	var half := size * 0.5
	top.polygon = PackedVector2Array([-half, Vector2(half.x, -half.y), half, Vector2(-half.x, half.y)])
