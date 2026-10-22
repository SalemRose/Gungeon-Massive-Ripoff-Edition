class_name HubStation
extends Node2D
## A usable thing in the hub: the dungeon door, the unlock terminal...
## Walk up, press Interact (E / Y) and it emits `used`; the hub decides what
## that means. Built from a few placeholder shapes under `Visual`.
##
##     var door := HubStation.new()
##     door.caption = "DUNGEON"
##     door.color = Color(0.5, 0.2, 0.6)
##     door.used.connect(go_to_dungeon)
##
## INTERACTION: same contract as Stairs / Chest ("interactables" group with
## can_interact / interact / get_prompt).
## ART: replace the polygon under `Visual` with a sprite.

signal used

@export var caption: String = "STATION"
@export var color: Color = Color(0.3, 0.5, 0.8)

const PROMPT_RANGE := 48.0

var _player: Player
var _prompt: Label


func _ready() -> void:
	add_to_group("interactables")
	var visual := Node2D.new()
	visual.name = "Visual"
	add_child(visual)
	var body := Polygon2D.new()
	body.polygon = PackedVector2Array([Vector2(-18, -22), Vector2(18, -22), Vector2(18, 14), Vector2(-18, 14)])
	body.color = color
	visual.add_child(body)
	var screen := Polygon2D.new()
	screen.polygon = PackedVector2Array([Vector2(-12, -16), Vector2(12, -16), Vector2(12, 0), Vector2(-12, 0)])
	screen.color = color.lightened(0.5)
	visual.add_child(screen)
	var caption_label := Label.new()
	caption_label.text = caption
	caption_label.position = Vector2(-45.0, 16.0)
	caption_label.size = Vector2(90.0, 16.0)
	caption_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caption_label.add_theme_font_size_override("font_size", 11)
	add_child(caption_label)
	_prompt = Label.new()
	_prompt.visible = false
	_prompt.position = Vector2(-10.0, -44.0)
	_prompt.add_theme_font_size_override("font_size", 13)
	add_child(_prompt)


func _process(_delta: float) -> void:
	if not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player") as Player
	_prompt.visible = _player != null and global_position.distance_to(_player.global_position) <= PROMPT_RANGE
	if _prompt.visible:
		_prompt.text = get_prompt(_player)


# --- Interaction (called by the player) ---------------------------------------

func can_interact(_player_node: Player) -> bool:
	return true


func get_prompt(player_node: Player) -> String:
	return "Y" if player_node.using_gamepad else "E"


func interact(_player_node: Player) -> void:
	used.emit()
