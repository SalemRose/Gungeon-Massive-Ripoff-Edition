class_name EnemyAttack
extends Resource
## One enemy attack, as data (a .tres file, see entities/enemies/attacks/).
##
## A single flexible recipe covers every classic bullet-hell pattern. An attack
## fires `shots` volleys, `shot_interval` seconds apart. Each volley fires
## `bullets_per_shot` bullets spread over `arc_degrees`. Between volleys the
## whole fan can turn by `rotation_per_shot_degrees`.
##
##   AIMED BURST  aim_at_player, arc 0,   1 bullet,  3 shots          (Bullet Kin)
##   FAN          aim_at_player, arc 40,  5 bullets, 1 shot           (Shotgun Kin)
##   RING         not aimed,     arc 360, 14 bullets, 1+ shots        (Ring Turret)
##   SPIRAL       not aimed,     arc 360, 3 bullets, 28 shots,
##                rotation 17 degrees per shot                        (Spiral Mage)
##
## Invent new patterns by changing numbers, no code needed. Enemy.gd runs it.

const DEFAULT_BULLET: PackedScene = preload("res://entities/projectiles/enemy_bullet.tscn")

@export var display_name: String = "Attack"

@export_group("Timing")
## Warning time before the first bullet, so the player can react.
@export var windup_time: float = 0.5
## Pause after the attack ends before the next one may begin.
@export var cooldown: float = 2.0
## Cooldown varies by up to +/- this many seconds, so groups desynchronise.
@export var cooldown_jitter: float = 0.4
## Only attacks when the player is closer than this (pixels) and visible.
@export var attack_range: float = 300.0

@export_group("Pattern")
## Number of volleys.
@export var shots: int = 1
## Seconds between volleys.
@export var shot_interval: float = 0.15
@export var bullets_per_shot: int = 1
## Angle the bullets of one volley are spread across. 360 = a full ring.
@export_range(0.0, 360.0) var arc_degrees: float = 0.0
## true: the volley points at the player. false: it points at start_angle_degrees.
@export var aim_at_player: bool = true
@export var start_angle_degrees: float = 0.0
@export var random_start_angle: bool = false
## The fan turns by this much after every volley. Non-zero = spiral.
@export var rotation_per_shot_degrees: float = 0.0

@export_group("Bullet")
## Leave empty for the default round enemy bullet.
@export var bullet_scene: PackedScene
@export var bullet_speed: float = 160.0
## In half-hearts: 2 = one full heart.
@export var bullet_damage: float = 2.0
@export var bullet_lifetime: float = 5.0
@export var bullet_color: Color = Color(1.0, 0.35, 0.6)


## The directions (radians) of every bullet in volley number `shot_index`.
## `aim_angle` is the angle from the enemy to the player. `random_offset` is
## the per-attack random start angle (only used if random_start_angle is set).
func get_angles(shot_index: int, aim_angle: float, random_offset: float = 0.0) -> PackedFloat32Array:
	var angles := PackedFloat32Array()
	var count := maxi(1, bullets_per_shot)

	var base := aim_angle if aim_at_player else deg_to_rad(start_angle_degrees)
	if random_start_angle and not aim_at_player:
		base += random_offset
	base += deg_to_rad(rotation_per_shot_degrees) * shot_index

	for i in count:
		var offset := 0.0
		if arc_degrees >= 360.0:
			offset = TAU * float(i) / float(count)  # full ring: no bullet doubled at the seam
		elif count > 1:
			offset = deg_to_rad(arc_degrees) * (float(i) / float(count - 1) - 0.5)
		angles.append(base + offset)
	return angles


func get_bullet_scene() -> PackedScene:
	return bullet_scene if bullet_scene else DEFAULT_BULLET
