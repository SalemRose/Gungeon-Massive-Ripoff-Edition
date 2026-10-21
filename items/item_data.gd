class_name ItemData
extends Resource
## One passive item, described as DATA (a .tres file in items/data/).
##
## A passive item changes the player's stats for the rest of the run. To add a
## new item you only create a new ItemData .tres: no code needed. The fields
## are plain numbers so the system stays simple:
##
##   * `*_mult` fields are MULTIPLIERS. 1.0 = no change, 1.25 = +25%.
##     Several items multiply together (two +25% items = x1.5625).
##   * `*_bonus` fields are FLAT ADDITIONS applied once, when the item is taken.
##
## ART: `icon_color` is the placeholder look. Later set `icon` to a texture and
## the pedestal / HUD will use it instead.

## Unique key used by saves and the run snapshot. Keep it stable once shipped.
@export var id: StringName = &""
@export var display_name: String = "Item"
@export_multiline var description: String = ""
## Placeholder icon colour (a diamond of this colour is drawn).
@export var icon_color: Color = Color(0.9, 0.8, 0.3)
## Optional real icon. Empty = use the coloured diamond.
@export var icon: Texture2D

@export_group("Stat multipliers")
## Bullet / beam / orb damage of every gun.
@export var damage_mult: float = 1.0
## Shots per second of every gun.
@export var fire_rate_mult: float = 1.0
## Walking speed (also scales the roll).
@export var move_speed_mult: float = 1.0

@export_group("Instant bonuses")
## Extra max health (2 = one heart). Also heals by the same amount.
@export var max_health_bonus: int = 0
## Extra blanks given immediately.
@export var blanks_bonus: int = 0
