extends Node
## Player OPTIONS: window resolution, fullscreen, music and sound-effect volume.
## (An autoload named `GameSettings`.) The values live in SaveData under the
## "settings" key, so they persist between sessions, and they are applied to the
## window and the audio buses as soon as they change and at game start.
##
##     GameSettings.set_fullscreen(true)
##     GameSettings.set_music_volume(0.5)     # 0.0 (mute) .. 1.0 (full)
##     GameSettings.resolution_index          # index into RESOLUTIONS
##
## AUDIO: the game has no sounds yet, but the "Music" and "SFX" buses are
## created here. When you add audio, set each AudioStreamPlayer's `bus` to
## "Music" or "SFX" and the sliders will control it.
##
## Erasing progress (New Game) does NOT reset options: SaveData.reset_all()
## keeps the "settings" entry.

signal changed

## The standard 16:9 window sizes offered in the menu.
const RESOLUTIONS: Array[Vector2i] = [
	Vector2i(1280, 720),
	Vector2i(1366, 768),
	Vector2i(1600, 900),
	Vector2i(1920, 1080),
	Vector2i(2560, 1440),
]
const DEFAULT_RESOLUTION_INDEX := 0
const MUSIC_BUS := "Music"
const SFX_BUS := "SFX"

var resolution_index: int = DEFAULT_RESOLUTION_INDEX
var fullscreen: bool = false
var music_volume: float = 1.0
var sfx_volume: float = 1.0


func _ready() -> void:
	_ensure_bus(MUSIC_BUS)
	_ensure_bus(SFX_BUS)
	load_from_save()
	apply_all()


## Reads the values from SaveData (missing ones keep their defaults).
func load_from_save() -> void:
	var saved: Dictionary = _save().get_value("settings", {})
	resolution_index = clampi(int(saved.get("resolution_index", DEFAULT_RESOLUTION_INDEX)), 0, RESOLUTIONS.size() - 1)
	fullscreen = bool(saved.get("fullscreen", false))
	music_volume = clampf(float(saved.get("music_volume", 1.0)), 0.0, 1.0)
	sfx_volume = clampf(float(saved.get("sfx_volume", 1.0)), 0.0, 1.0)


func set_resolution(index: int) -> void:
	resolution_index = clampi(index, 0, RESOLUTIONS.size() - 1)
	_changed()


func set_fullscreen(on: bool) -> void:
	fullscreen = on
	_changed()


func set_music_volume(value: float) -> void:
	music_volume = clampf(value, 0.0, 1.0)
	_changed()


func set_sfx_volume(value: float) -> void:
	sfx_volume = clampf(value, 0.0, 1.0)
	_changed()


## "1920 x 1080", used by the menu.
static func resolution_text(index: int) -> String:
	return "%d x %d" % [RESOLUTIONS[index].x, RESOLUTIONS[index].y]


## Pushes the current values to the window and the audio buses.
func apply_all() -> void:
	_apply_window()
	_apply_volume(MUSIC_BUS, music_volume)
	_apply_volume(SFX_BUS, sfx_volume)


func _changed() -> void:
	_save().set_value("settings", {
		"resolution_index": resolution_index,
		"fullscreen": fullscreen,
		"music_volume": music_volume,
		"sfx_volume": sfx_volume,
	})
	apply_all()
	changed.emit()


func _apply_window() -> void:
	# A headless run (tests, servers) has no window to resize.
	if DisplayServer.get_name() == "headless":
		return
	if fullscreen:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		var size := RESOLUTIONS[resolution_index]
		DisplayServer.window_set_size(size)
		# Re-centre on the screen the window is on.
		var screen := DisplayServer.window_get_current_screen()
		var area := DisplayServer.screen_get_usable_rect(screen)
		DisplayServer.window_set_position(area.position + (area.size - size) / 2)


## Linear 0..1 slider value -> decibels. 0 mutes the bus.
func _apply_volume(bus_name: String, linear: float) -> void:
	var index := AudioServer.get_bus_index(bus_name)
	if index < 0:
		return
	AudioServer.set_bus_mute(index, linear <= 0.001)
	AudioServer.set_bus_volume_db(index, linear_to_db(maxf(linear, 0.001)))


func _ensure_bus(bus_name: String) -> void:
	if AudioServer.get_bus_index(bus_name) < 0:
		AudioServer.add_bus()
		var index := AudioServer.bus_count - 1
		AudioServer.set_bus_name(index, bus_name)
		AudioServer.set_bus_send(index, "Master")


func _save() -> Node:
	return get_node("/root/SaveData")
