class_name WeaponManager
extends Node
## Lives on the Player. Reads the shoot / reload / swap inputs, owns the list of
## guns the player carries, and tells the active Weapon when to fire.
##
## Division of labour:
##   WeaponManager = input + inventory   (this file)
##   Weapon        = ammo + firing rules (weapon.gd)
##   WeaponData    = numbers             (weapons/data/*.tres)
##   Bullet        = flight + hits       (entities/projectiles/bullet.gd)

signal weapon_changed(weapon: Weapon)

## Guns the player starts with. Edit in the Inspector on the WeaponManager node.
@export var starting_weapons: Array[WeaponData] = []
## A semi-auto click made up to this long before the gun is ready still fires.
@export var shoot_buffer_time: float = 0.12

var weapons: Array[Weapon] = []
var current: Weapon
var current_index: int = -1

var _shoot_buffer_left: float = 0.0

@onready var player: Player = get_parent() as Player


func _ready() -> void:
	for data in starting_weapons:
		add_weapon(data)
	if not weapons.is_empty():
		switch_to(0)


func _physics_process(delta: float) -> void:
	if current == null:
		return

	_shoot_buffer_left = maxf(0.0, _shoot_buffer_left - delta)
	if Input.is_action_just_pressed("shoot"):
		_shoot_buffer_left = shoot_buffer_time

	if Input.is_action_just_pressed("reload"):
		current.start_reload()

	# No shooting while rolling or dead (matches Gungeon).
	if player.state != Player.State.NORMAL:
		return

	var wants_to_fire := false
	match current.data.fire_mode:
		WeaponData.FireMode.AUTO:
			wants_to_fire = Input.is_action_pressed("shoot")
		WeaponData.FireMode.SEMI:
			wants_to_fire = _shoot_buffer_left > 0.0

	if not wants_to_fire:
		return

	# Completely out of ammo: fall back to a gun that still has some.
	if current.is_out_of_ammo():
		_switch_to_gun_with_ammo()
		return

	if current.try_fire(player.muzzle.global_position, player.aim_direction):
		_shoot_buffer_left = 0.0
		player.add_shake(current.data.screen_shake)
		player.play_muzzle_flash()


## Mouse wheel and D-pad produce one-off events, so swapping is handled here
## instead of being polled every frame (a polled wheel tick can be missed).
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("weapon_next"):
		cycle(1)
	elif event.is_action_pressed("weapon_prev"):
		cycle(-1)


# --- Inventory --------------------------------------------------------------------

func add_weapon(data: WeaponData) -> Weapon:
	var weapon := Weapon.new()
	add_child(weapon)
	weapon.setup(data, player)
	weapons.append(weapon)
	return weapon


func switch_to(index: int) -> void:
	if weapons.is_empty():
		return
	index = wrapi(index, 0, weapons.size())
	if index == current_index:
		return
	if current:
		current.cancel_reload()  # swapping interrupts a reload
	current_index = index
	current = weapons[index]
	_shoot_buffer_left = 0.0
	player.set_gun_color(current.data.color)
	weapon_changed.emit(current)


func cycle(step: int) -> void:
	switch_to(current_index + step)


func _switch_to_gun_with_ammo() -> void:
	for i in weapons.size():
		if not weapons[i].is_out_of_ammo():
			switch_to(i)
			return
