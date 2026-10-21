class_name Chest
extends Node2D
## A treasure chest: press Interact (E / Y) next to it and it bursts open,
## dropping its contents as pickups on the floor around it.
##
## `contents` is a list of [Pickup.Kind, amount] pairs, decided when the floor
## is built (so the same seed always has the same loot). `item` (optional) is
## a passive item: opening the chest sets a free ItemPedestal with it next to
## the loot.
##
##     chest.contents = [[Pickup.Kind.HEART_CONTAINER, 1]]
##
## INTERACTION: same contract as Table and ShopItem: joins "interactables" and
## provides can_interact(player), interact(player) and get_prompt().
##
## ART: everything visible is under `Visual` (Body and Lid polygons; replace
## with an animated sprite and call it from _play_open()).

signal opened

## Array of [kind, amount].
var contents: Array = [[Pickup.Kind.HEART_CONTAINER, 1]]
## Optional passive item inside (decided at build time, like contents).
var item: ItemData
var is_open: bool = false

const PROMPT_RANGE := 44.0
const ITEM_PEDESTAL_SCENE: PackedScene = preload("res://levels/props/item_pedestal.tscn")
## How far the loot scatters from the chest.
const SCATTER := 26.0

var _player: Player

@onready var visual: Node2D = $Visual
@onready var lid: Polygon2D = $Visual/Lid
@onready var prompt: Label = $Prompt


func _ready() -> void:
	add_to_group("interactables")


func _process(_delta: float) -> void:
	if not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player") as Player
	prompt.visible = _player != null and can_interact(_player) and global_position.distance_to(_player.global_position) <= PROMPT_RANGE
	if prompt.visible:
		prompt.text = get_prompt(_player)


# --- Interaction (called by the player) ---------------------------------------

func can_interact(_player_node: Player) -> bool:
	return not is_open


func get_prompt(player_node: Player) -> String:
	return "Y" if player_node.using_gamepad else "E"


func interact(_player_node: Player) -> void:
	open()


## Opens the chest and drops everything inside. Safe to call twice.
func open() -> void:
	if is_open:
		return
	is_open = true
	prompt.visible = false
	_play_open()
	# Spread the loot evenly on a small circle below the chest.
	var count := contents.size()
	for i in count:
		var angle := PI * 0.25 + PI * 0.5 * (float(i) + 0.5) / maxf(count, 1.0)
		var spot := global_position + Vector2.from_angle(angle) * SCATTER
		var pickup := Pickup.spawn(get_parent(), spot, contents[i][0])
		pickup.amount = contents[i][1]
	if item != null:
		var pedestal := ITEM_PEDESTAL_SCENE.instantiate() as ItemPedestal
		pedestal.item = item
		pedestal.position = position + Vector2(0.0, 52.0)
		get_parent().add_child(pedestal)
	opened.emit()


## PLACEHOLDER animation: the lid flips up and the chest dims.
func _play_open() -> void:
	var tween := create_tween().set_parallel(true)
	tween.tween_property(lid, "position:y", -9.0, 0.15)
	tween.tween_property(lid, "modulate", Color(1.0, 0.9, 0.5), 0.15)
	tween.tween_property(visual, "scale", Vector2.ONE, 0.15)
