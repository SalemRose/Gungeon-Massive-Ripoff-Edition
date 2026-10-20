class_name ShopItem
extends Node2D
## One thing for sale on a shop pedestal. Walk up, press Interact (E / Y) and
## the price is taken from your coins.
##
##     var item := ShopItem.new() ... or instance shop_item.tscn
##     item.kind = Pickup.Kind.HEART
##     item.price = 12
##
## It sells what a Pickup gives (heart, ammo, blank) and reuses Pickup's rules,
## so you are never charged for something that would do nothing (a heart at
## full health). It sells one unit, then shows SOLD. Guns and passive items
## will be added as new kinds of offer in the item system (step 11).
##
## INTERACTION: same contract as Table: it joins the "interactables" group and
## provides can_interact(player), interact(player) and get_prompt().
##
## ART: everything visible is under `Visual` (pedestal + item icon).

signal bought(kind: int, price: int)

@export var kind: Pickup.Kind = Pickup.Kind.HEART
@export var price: int = 10
## true after purchase.
var sold: bool = false

const PROMPT_RANGE := 44.0

var _player: Player

@onready var visual: Node2D = $Visual
@onready var price_label: Label = $PriceLabel
@onready var prompt: Label = $Prompt


func _ready() -> void:
	add_to_group("interactables")
	# Icon on top of the pedestal. The pedestal polygon is in the scene.
	var icon := Pickup.make_icon(kind)
	icon.name = "Icon"
	icon.position = Vector2(0.0, -4.0)
	visual.add_child(icon)
	price_label.text = str(price)


func _process(_delta: float) -> void:
	if not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player") as Player
	if _player == null:
		return
	var affordable := _player.coins >= price
	price_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2) if affordable else Color(0.8, 0.35, 0.35))
	var near := not sold and global_position.distance_to(_player.global_position) <= PROMPT_RANGE
	prompt.visible = near
	if near:
		prompt.text = get_prompt(_player)


# --- Interaction (called by the player) ---------------------------------------

func can_interact(_player_node: Player) -> bool:
	return not sold


func get_prompt(player_node: Player) -> String:
	return "Y" if player_node.using_gamepad else "E"


## Tries to buy. Returns true if the sale went through.
func interact(player_node: Player) -> bool:
	if sold:
		return false
	if not Pickup.is_useful(player_node, kind):
		FloatingText.spawn(get_parent(), global_position + Vector2(0.0, -26.0), "NO NEED", Color(0.8, 0.8, 0.8), 10)
		return false
	if not player_node.spend_coins(price):
		FloatingText.spawn(get_parent(), global_position + Vector2(0.0, -26.0), "NOT ENOUGH", Color(0.9, 0.35, 0.35), 10)
		return false
	var result := Pickup.apply_effect(player_node, kind)
	FloatingText.spawn(get_parent(), global_position + Vector2(0.0, -26.0), result.label, result.color, 11)
	sold = true
	visual.get_node("Icon").visible = false
	price_label.text = "SOLD"
	price_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.65))
	prompt.visible = false
	bought.emit(kind, price)
	return true
