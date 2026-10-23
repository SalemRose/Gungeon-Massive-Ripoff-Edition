extends CanvasLayer
## In-game HUD: health, current gun, ammo and reload progress.
##
## It POLLS the player every frame instead of connecting to signals. That is
## simpler, can never get out of sync, and costs nothing for a few labels.
## (Signals are better for events that happen rarely.)

@onready var health_bar: ProgressBar = $Root/HealthBar
@onready var health_label: Label = $Root/HealthLabel
@onready var weapon_label: Label = $Root/WeaponLabel
@onready var ammo_label: Label = $Root/AmmoLabel
@onready var reload_bar: ProgressBar = $Root/ReloadBar
@onready var blank_label: Label = $Root/BlankLabel
@onready var coin_label: Label = $Root/CoinLabel
@onready var room_label: Label = $RoomLabel
@onready var salve_label: Label = $Root/SalveLabel

var _player: Player


func _process(_delta: float) -> void:
	_update_room_label()
	if _player == null:
		_player = get_tree().get_first_node_in_group("player") as Player
		return

	# Health is stored in half-hearts, so 6 = three hearts.
	health_bar.max_value = _player.max_health
	health_bar.value = _player.health
	health_label.text = "%d / %d" % [_player.health, _player.max_health]
	blank_label.text = "Blanks: %d" % _player.blanks
	coin_label.text = "Coins: %d" % _player.coins
	salve_label.text = "Salves: %d [G]" % _player.salves

	var manager := _player.weapon_manager
	var weapon := manager.current
	if weapon == null:
		return

	weapon_label.text = "%s  (%d/%d)" % [weapon.data.display_name, manager.current_index + 1, manager.weapons.size()]
	ammo_label.text = weapon.ammo_text()
	# The same bar shows reload progress, or the charge of a charge gun.
	var charging := weapon.charge > 0.0
	reload_bar.visible = weapon.reloading or charging
	reload_bar.value = weapon.charge if charging else weapon.reload_progress()
	if weapon.reloading:
		ammo_label.text = "RELOADING"


## Shows wave progress while the player is locked in a fight, otherwise nothing.
func _update_room_label() -> void:
	var text := ""
	for room in get_tree().get_nodes_in_group("rooms"):
		text = (room as Room).status_text()
		if text != "":
			break
	room_label.text = text
