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

	# No shooting while rolling or dead (matches Gungeon). A charge, a beam or
	# a burst in progress is dropped.
	if player.state != Player.State.NORMAL:
		current.cancel_hold()
		return

	# Charge and beam guns work on holding the button, not on clicks.
	match current.data.fire_mode:
		WeaponData.FireMode.CHARGE:
			_process_charge(delta)
			return
		WeaponData.FireMode.BEAM:
			_process_beam(delta)
			return

	var wants_to_fire := false
	match current.data.fire_mode:
		WeaponData.FireMode.AUTO:
			wants_to_fire = Input.is_action_pressed("shoot")
		WeaponData.FireMode.SEMI, WeaponData.FireMode.BURST:
			wants_to_fire = _shoot_buffer_left > 0.0

	if not wants_to_fire:
		return

	# Completely out of ammo: fall back to a gun that still has some.
	if current.is_out_of_ammo():
		_switch_to_gun_with_ammo()
		return

	if current.try_fire(player.muzzle.global_position, player.aim_direction):
		_shoot_buffer_left = 0.0


## CHARGE: charges while held, fires on release.
func _process_charge(delta: float) -> void:
	if current.is_out_of_ammo():
		if Input.is_action_pressed("shoot"):
			_switch_to_gun_with_ammo()
		return
	if Input.is_action_pressed("shoot"):
		current.hold_charge(delta)
	else:
		current.release_charge(player.muzzle.global_position, player.aim_direction)


## BEAM: on while the button is held.
func _process_beam(delta: float) -> void:
	if not Input.is_action_pressed("shoot"):
		current.stop_beam()
		return
	if current.is_out_of_ammo():
		current.stop_beam()
		_switch_to_gun_with_ammo()
		return
	current.hold_beam(delta, player.muzzle.global_position, player.aim_direction)


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
	weapon.fired.connect(_on_weapon_fired.bind(weapon))   # every shot, burst follow-ups included
	weapons.append(weapon)
	return weapon


## Camera shake and muzzle flash for each shot.
func _on_weapon_fired(weapon: Weapon) -> void:
	player.add_shake(weapon.data.screen_shake)
	player.play_muzzle_flash()


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
