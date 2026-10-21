class_name Stairs
extends Node2D
## The way down. Appears in the boss room once the boss is dead; press
## Interact (E / Y) next to it to leave the floor.
##
## On the last floor of a run it is a victory exit instead (the label says so);
## the floor level decides what using it does, this node only reports it:
##
##     stairs.used.connect(level.descend)
##
## INTERACTION: same contract as Table / ShopItem / Chest.
## ART: everything visible is under `Visual`.

signal used

## Text under the stairs ("DOWN", or "VICTORY" on the last floor).
@export var caption: String = "DOWN"

const PROMPT_RANGE := 48.0

var _player: Player
var _used: bool = false

@onready var prompt: Label = $Prompt
@onready var caption_label: Label = $Caption


func _ready() -> void:
	add_to_group("interactables")
	caption_label.text = caption


func _process(_delta: float) -> void:
	if not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player") as Player
	prompt.visible = _player != null and can_interact(_player) and global_position.distance_to(_player.global_position) <= PROMPT_RANGE
	if prompt.visible:
		prompt.text = get_prompt(_player)


# --- Interaction (called by the player) ---------------------------------------

func can_interact(_player_node: Player) -> bool:
	return not _used


func get_prompt(player_node: Player) -> String:
	return "Y" if player_node.using_gamepad else "E"


func interact(_player_node: Player) -> void:
	if _used:
		return
	_used = true
	prompt.visible = false
	used.emit()
