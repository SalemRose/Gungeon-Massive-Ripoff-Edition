class_name BossPhase
extends Resource
## One stage of a boss fight, as data (.tres). A Boss lists its phases from
## first to last; it moves to the next one when its health falls to
## `health_threshold`. Inside a phase it cycles through `attacks` in order.
##
## Tune a fight by editing numbers here, no code needed.

## Name shown nowhere yet, handy in the Inspector and the debug text.
@export var display_name: String = "Phase"
## The phase starts when health is at or below this FRACTION of max health.
## The first phase uses 1.0. Keep phases in falling order: 1.0, 0.6, 0.3.
@export_range(0.0, 1.0) var health_threshold: float = 1.0

@export_group("Movement")
@export var movement: Enemy.Movement = Enemy.Movement.APPROACH
@export var move_speed: float = 50.0
@export var preferred_distance: float = 170.0

@export_group("Attacks")
## Used one after another, then round again.
@export var attacks: Array[EnemyAttack] = []
