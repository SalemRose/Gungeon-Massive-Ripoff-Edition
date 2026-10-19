class_name RoomWave
extends Resource
## One wave of enemies inside a Room. A room holds a list of these and plays
## them in order: the next wave starts once the previous one is dead.
##
## Waves are plain data, so the floor generator can create them in code too:
##     var wave := RoomWave.new()
##     wave.enemies = [bullet_kin_scene, bullet_kin_scene]

## Which enemies appear. Add the same scene twice to get two of them.
@export var enemies: Array[PackedScene] = []
## Seconds of calm before this wave appears (after the doors close for the
## first wave, after the previous wave dies for the others).
@export var delay: float = 1.0
