class_name WeaponData
extends Resource
## The stats of ONE gun, stored as a .tres file (see weapons/data/).
##
## WHY A RESOURCE?
## A new gun is a new .tres file you fill in from the Inspector: no code, no
## scene. Weapon.gd reads these numbers and does the actual shooting. Only a
## gun with truly new behaviour (homing, beams...) will need new code, and that
## goes into the bullet, not into every gun.
##
## To make a gun: FileSystem dock > right-click weapons/data > New Resource >
## WeaponData.

enum FireMode {
	SEMI,  ## One shot per click. Holding the button does nothing extra.
	AUTO,  ## Keeps firing while the button is held.
}

@export var display_name: String = "Gun"
## Tints the bullets and the placeholder gun sprite so guns are easy to tell apart.
@export var color: Color = Color(1.0, 0.9, 0.4)

@export_group("Firing")
@export var fire_mode: FireMode = FireMode.SEMI
## Shots per second.
@export var fire_rate: float = 5.0
## Bullets per shot (a shotgun uses several).
@export var projectiles_per_shot: int = 1
## Total cone the bullets of ONE shot are evenly spread across, in degrees.
@export var spread_degrees: float = 0.0
## Random error added to every bullet, +/- degrees. Higher = less accurate.
@export var inaccuracy_degrees: float = 0.0

@export_group("Bullet")
## Leave empty to use the default bullet. Set it later for guns with their own
## bullet art or behaviour.
@export var bullet_scene: PackedScene
@export var damage: float = 5.0
@export var bullet_speed: float = 500.0
## Seconds before the bullet disappears: speed * lifetime = range in pixels.
@export var bullet_lifetime: float = 1.2
## Each bullet's speed varies by up to +/- this fraction (0.1 = 10%).
@export_range(0.0, 0.5) var speed_variance: float = 0.0
## How many times a bullet can bounce off walls before it breaks.
@export var bounces: int = 0
## How many enemies a bullet can pass through (0 = stops at the first).
@export var pierce: int = 0

@export_group("Ammo")
## Bullets per magazine. A reload refills it from the reserve.
@export var magazine_size: int = 12
## Infinite guns (the starter pistol) never run out and always reload.
@export var infinite_ammo: bool = false
@export var max_reserve_ammo: int = 120
@export var starting_reserve_ammo: int = 60
@export var reload_time: float = 1.2

@export_group("Feel")
## Camera shake per shot, in pixels.
@export var screen_shake: float = 1.0
