class_name ItemPedestal
extends Node2D
## A passive item resting on a pedestal. Press Interact (E / Y) next to it to
## take it. With `price` > 0 it is a SHOP offer and costs coins; with price 0
## (chest rewards) it is free.
##
##     var ped := ITEM_PEDESTAL_SCENE.instantiate() as ItemPedestal
##     ped.item = ItemPool.find(&"heavy_rounds")
##     ped.price = 40
##
## INTERACTION: same contract as Chest / ShopItem ("interactables" group with
## can_interact / interact / get_prompt).
##
## ART: everything visible is under `Visual` (pedestal + icon).

signal taken(item: ItemData)

@export var item: ItemData
@export var price: int = 0
var is_taken: bool = false

const PROMPT_RANGE := 44.0

var _player: Player

@onready var visual: Node2D = $Visual
@onready var price_label: Label = $PriceLabel
@onready var name_label: Label = $NameLabel
@onready var prompt: Label = $Prompt


func _ready() -> void:
	add_to_group("interactables")
	if item != null:
		visual.add_child(make_icon(item))
		name_label.text = item.display_name
	price_label.text = str(price) if price > 0 else ""


## Builds the icon node for an item: its texture if it has one, else a diamond.
static func make_icon(item_data: ItemData) -> Node2D:
	var node: Node2D
	if item_data.icon != null:
		var sprite := Sprite2D.new()
		sprite.texture = item_data.icon
		node = sprite
	else:
		var poly := Polygon2D.new()
		poly.polygon = PackedVector2Array([Vector2(0, -9), Vector2(8, 0), Vector2(0, 9), Vector2(-8, 0)])
		poly.color = item_data.icon_color
		node = poly
	node.name = "Icon"
	node.position = Vector2(0.0, -8.0)
	return node


func _process(_delta: float) -> void:
	if not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player") as Player
	if _player == null:
		return
	if price > 0 and not is_taken:
		var affordable := _player.coins >= price
		price_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2) if affordable else Color(0.8, 0.35, 0.35))
	var near := not is_taken and global_position.distance_to(_player.global_position) <= PROMPT_RANGE
	prompt.visible = near
	if near:
		prompt.text = get_prompt(_player)


# --- Interaction (called by the player) ---------------------------------------

func can_interact(_player_node: Player) -> bool:
	return not is_taken and item != null


func get_prompt(player_node: Player) -> String:
	return "Y" if player_node.using_gamepad else "E"


## Takes the item (paying if it has a price). Returns true on success.
func interact(player_node: Player) -> bool:
	if is_taken or item == null:
		return false
	if price > 0 and not player_node.spend_coins(price):
		FloatingText.spawn(get_parent(), global_position + Vector2(0.0, -30.0), "NOT ENOUGH", Color(0.9, 0.35, 0.35), 10)
		return false
	player_node.add_item(item)
	FloatingText.spawn(get_parent(), global_position + Vector2(0.0, -30.0), item.display_name.to_upper(), item.icon_color, 11)
	is_taken = true
	visual.get_node("Icon").visible = false
	prompt.visible = false
	name_label.text = ""
	price_label.text = "SOLD" if price > 0 else ""
	taken.emit(item)
	return true
