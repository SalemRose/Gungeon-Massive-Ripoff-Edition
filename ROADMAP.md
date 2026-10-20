# Gungeon Massive Ripoff Edition: roadmap

Godot 4.7.2, GDScript. A roguelite take on Enter the Gungeon: connected-room floors, bullet-hell gunplay, last-resort melee, and a hub with permanent unlocks. Art is placeholder shapes for now; everything visible lives under a `Visual` node so final art can be swapped in later.

Working style: small segments, one at a time, each tested before the next. Legend: [x] done, [ ] to do.

## Done

### 1. Foundation
- [x] Input (keyboard/mouse and gamepad), movement, aiming, dodge roll with i-frames

### 2. Guns and bullets
- [x] Data-driven weapons (`WeaponData` .tres), ammo and reload, bounce/pierce
- [x] 4 guns: pistol (infinite), SMG, shotgun, ricochet; ammo HUD

### 3. Enemies
- [x] Enemy base + `EnemyAttack` resource (aimed burst, fan, ring, spiral)
- [x] Bullet Kin, Shotgun Kin, Ring Turret, Spiral Mage; health bar

### 4. Rooms
- [x] Room builds walls and doorways from size + exits
- [x] Locking doors, enemy waves (`RoomWave`), test level

### 5. Defensive tools
- [x] 5a Blank (Q / left shoulder): clears bullets, knockback, i-frames
- [x] 5b Flippable tables (E / Y): cover against enemy bullets, generic interactables

### 6. Melee
- [x] 6a Melee swing: short range, cooldown, low damage (a last resort)
- [x] 6b Bullet deflection on the swing

### 7. Floors
- [x] 7a Seeded floor generator (pure data, `FloorLayout`)
- [x] 7b Build rooms from a layout and link them with corridors (`FloorBuilder`)
- [x] 7c Room camera: held inside the room, free in corridors
- [x] 7d Minimap
- [x] 7e Enemy pathfinding (A* grid per room)

### 8. Economy (in progress)
- [x] 8a Pickups: hearts, ammo, blanks; enemy drops
- [x] 8b Coins and HUD display

## To do, in order

### 8. Economy (rest)
- [ ] 8c Shop room: items for sale, buy with coins
- [ ] 8d Treasure room: free item / chest

### 9. Boss and run structure
- [ ] 9a Boss base class and the first boss
- [ ] 9b Stairs to the next floor, multi-floor runs

### 10. More guns (six more, for 10 total)
- [ ] 10a-c Homing, burst, charge, beam, boomerang, orbit

### 11. Items
- [ ] 11a Item system
- [ ] 11b First five passive items

### 12. Meta-progression
- [ ] 12a Save system
- [ ] 12b Permanent currency and unlocks
- [ ] 12c Hub scene

### 13. Menus
- [ ] 13a Main menu (title, new game, load, settings, quit)
- [ ] 13b Settings (resolution presets, fullscreen, music volume, sfx volume)
- [ ] 13c Pause menu

### 14. Polish
- [ ] 14 Final art swap pass

## Notes
- Physics layers: 1 world, 2 player, 3 enemy, 4 player projectile, 5 enemy projectile, 6 pickup, 7 interactable, 8 table, 9 cover.
- Position nodes BEFORE `add_child` when spawning bodies, or they briefly sit at the origin and can shove the player.
- Add new enum values at the END (they may end up in saved data).
- Draw order follows tree order: the floor node must come before the player.
- The original wish list is in `ROADMAP.txt` (main menu and settings), covered by segment 13.
