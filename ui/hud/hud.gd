extends CanvasLayer
## In-game HUD: current gun, ammo and reload progress.
##
## It POLLS the player's WeaponManager every frame instead of connecting to
## signals. That is simpler, can never get out of sync, and costs nothing for a
## few labels. (Signals are better for events that happen rarely.)

@onready var weapon_label: Label = $Root/WeaponLabel
@onready var ammo_label: Label = $Root/AmmoLabel
@onready var reload_bar: ProgressBar = $Root/ReloadBar

var _manager: WeaponManager


func _process(_delta: float) -> void:
	if _manager == null:
		var player := get_tree().get_first_node_in_group("player") as Player
		if player:
			_manager = player.weapon_manager
		return

	var weapon := _manager.current
	if weapon == null:
		return

	weapon_label.text = "%s  (%d/%d)" % [weapon.data.display_name, _manager.current_index + 1, _manager.weapons.size()]
	ammo_label.text = weapon.ammo_text()
	reload_bar.visible = weapon.reloading
	reload_bar.value = weapon.reload_progress()
	if weapon.reloading:
		ammo_label.text = "RELOADING"
