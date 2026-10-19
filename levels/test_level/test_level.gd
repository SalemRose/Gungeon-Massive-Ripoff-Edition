extends Node2D
## Throwaway level for trying rooms by hand: a start room, two fight rooms and
## an end room in a row. Walk east. Real floors come from the generator later.
##
## Debug keys (only in this level):
##   H  hurt the player by 1
##   K  kill every enemy in fighting rooms (enemies that are still fading in
##      can't be hurt, press again)

@onready var player: Player = $Player
@onready var debug_label: Label = $DebugLayer/DebugLabel


func _ready() -> void:
	player.died.connect(_on_player_died)


func _process(_delta: float) -> void:
	var lines: PackedStringArray = [
		player.debug_text(),
		"fps: %d" % Engine.get_frames_per_second(),
		"",
		"WASD/left stick: move   Mouse/right stick: aim   Space/RMB/A: roll",
		"LMB/RT: shoot   R/X: reload   Wheel/D-pad: swap gun   H: hurt   K: kill enemies",
		"",
	]
	for room in get_tree().get_nodes_in_group("rooms"):
		lines.append((room as Room).debug_text())
	debug_label.text = "\n".join(lines)


func _unhandled_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	if key.physical_keycode == KEY_H:
		player.take_damage(1)
	elif key.physical_keycode == KEY_K:
		for room in get_tree().get_nodes_in_group("rooms"):
			for enemy in (room as Room).get_enemies():
				enemy.take_damage(99999.0)


func _on_player_died() -> void:
	await get_tree().create_timer(1.5).timeout
	get_tree().reload_current_scene()
