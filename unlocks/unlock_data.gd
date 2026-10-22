class_name UnlockData
extends Resource
## One thing the player can buy PERMANENTLY with hub currency (a .tres file in
## unlocks/data/). Until it is bought, the gun or item it points at never shows
## up in your runs. Anything WITHOUT an unlock entry is available from the start
## (the Pistol, for example).
##
## To lock a new gun or item: create an UnlockData .tres pointing at it. No code.

enum Kind { GUN, ITEM }

## Unique key stored in the save file. Keep it stable once shipped.
@export var id: StringName = &""
@export var display_name: String = "Unlock"
@export_multiline var description: String = ""
## Price in hub currency.
@export var cost: int = 50
@export var kind: Kind = Kind.GUN
## What it unlocks: the file name (without .tres) of the gun in weapons/data/,
## or the item's `id`.
@export var target: StringName = &""
