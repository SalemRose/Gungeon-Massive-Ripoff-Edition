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

var _player: Player


func _process(_delta: float) -> void:
	if _player == null:
		_player = get_tree().get_first_node_in_group("player") as Player
		return

	# Health is stored in half-hearts, so 6 = three hearts.
	health_bar.max_value = _player.max_health
	health_bar.value = _player.health
	health_label.text = "%d / %d" % [_player.health, _player.max_health]

	var manager := _player.weapon_manager
	var weapon := manager.current
	if weapon == null:
		return

	weapon_label.text = "%s  (%d/%d)" % [weapon.data.display_name, manager.current_index + 1, manager.weapons.size()]
	ammo_label.text = weapon.ammo_text()
	reload_bar.visible = weapon.reloading
	reload_bar.value = weapon.reload_progress()
	if weapon.reloading:
		ammo_label.text = "RELOADING"
