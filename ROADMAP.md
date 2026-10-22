# Gungeon Massive Ripoff Edition: roadmap and status

Godot 4.7.2, GDScript, placeholder shapes for art (all visuals under a `Visual` node). Code layout: entities/, weapons/, levels/, ui/, autoload/.

## Standing instructions (from the project)

- Do not send any unmodified file (we save bandwidth): every delivery is a zip of ONLY new/changed files
- Always add notation (comments) to the scripts provided, for learning reasons
- Push to GitHub only when the user says so (the stop hook asking to push is declined each time)
- Keep reasoning efficient: achieve as much as possible in one day
- Explain briefly and efficiently what was done in every step

## Working style

- Small segments, strictly in order, one at a time; the user says "next" to advance
- Each segment: implement, test (headless), commit locally, zip changed files, send, brief explanation, update this roadmap
- Screenshots are internal checks only, never sent
- The user's own ROADMAP.txt (main menu and settings wishes) is theirs: do not touch it
- Local commits not yet pushed: 9b, 10a, 10b, 10c, 11a, 11b, 12a, 12b, roadmap (last pushed: ROADMAP.md update)

## Game summary

- Roguelite (not roguelike) in the style of Enter the Gungeon: connected-room floors (start, combat, shop, treasure, boss), 3 floors per run, bullet-hell gunplay, last-resort melee, blanks, flippable tables, limited ammo with an infinite starter pistol
- Roguelite meta: hub and permanent unlocks (steps 12a-12c)
- Keyboard/mouse and gamepad; placeholder art everywhere, swappable because everything visible is under a `Visual` node

## Done

1. Foundation (input, movement, aim, roll)
2. Guns/bullets (4 guns)
3. Enemies (4 types)
4. Rooms/doors/waves
5. 5a Blank
6. 5b Flippable tables
7. 6a Melee swing
8. 6b Bullet deflection
9. 7a Floor generator
10. 7b Build rooms + corridors
11. 7c Room camera
12. 7d Minimap
13. 7e Pathfinding
14. 8a Pickups (heart/ammo/blank) + drops
15. 8b Coins + HUD
16. 8c Shop room
17. 8d Treasure room (chest, heart containers)
18. 9a Boss base (phases) + first boss, The Warden
19. 9b Stairs + multi-floor runs (3 floors, state carried between floors)
20. 10a Homing gun (Seeker) + burst gun (Burst Rifle)
21. 10b Charge gun (Charge Cannon) + beam gun (Beam Emitter)
22. 10c Boomerang gun + orbit gun (Orbit Sphere): 10 guns in total
23. 11a Item system: ItemData resources (stat multipliers + flat bonuses), ItemPool, item pedestal; items appear in treasure chests and the shop, carry between floors
24. 11b First five passive items: Quick Boots, Rapid Trigger, Heart Locket, Blank Satchel, Sharp Rounds (plus Heavy Rounds from 11a = 6 items)
25. 12a Save system: SaveData autoload (versioned JSON in user://save.json, safe writes, corrupt-file backup, unlocks, currency, run stats); Run.end_run() records each finished run
26. 12b Permanent currency/unlocks: runs pay hub currency (5 + 10 per floor cleared + 30 for winning + half your leftover coins); UnlockData/UnlockCatalog lock 6 guns and 3 items until bought (Pistol, SMG, Shotgun, Ricochet and the other items are free)

## Next, in order

12c Hub scene \
13a Main menu \
13b Settings (resolutions, fullscreen, music/sfx volume) \
13c Pause menu \
14 Final art swap pass

## Notes

- Physics layers: 1 world, 2 player, 3 enemy, 4 player projectile, 5 enemy projectile, 6 pickup, 7 interactable, 8 table, 9 cover
- Position nodes BEFORE add_child when spawning bodies
- Add enum values at the END
- Draw order follows tree order: floor node before the player, corridors under the rooms (z_index -1) so they don't hide the doors
- Main scene is now levels/floor_level/floor_level.tscn (generated floors); test_level is the old hand-built one
- Interactables (tables, shop items, chests) join the "interactables" group and provide can_interact / interact / get_prompt
- `Run` (autoload) holds the run: seed, floor, and the player snapshot carried between floors; fixed-seed floor levels ignore it (tests/debug)
- A new boss = a scene inheriting enemy.tscn with boss.gd plus BossPhase .tres files (no new code)
- A new passive item = an ItemData .tres in items/data/ (stat multipliers + flat bonuses, no code); chests and the shop pick it up automatically
- Weapons are data: WeaponData .tres with fire modes SEMI, AUTO, BURST, CHARGE, BEAM, ORBIT plus homing/boomerang settings; a new gun = a new .tres (10 guns exist, all in player.tscn starting_weapons until the item system hands them out)
- Universal damage interface: `take_damage(amount) -> bool`; groups: player, bullets, enemies, rooms, interactables, bosses, orbit_orbs
- Floors are seeded: FloorGenerator.generate(seed, floor) -> FloorLayout, FloorBuilder.build(layout); same seed = same floor and loot. floor_level follows `Run` when seed_value == 0
- Enemy pathfinding: AStarGrid2D per Room (16 px cells), refreshed every 1.5 s
- Balance: boss The Warden 320 HP, phases at 100/60/30%, drops heart container + heart + 12 coins; shop prices heart 12, ammo 15, blank 20, item 35; chests: 40% item, 30% heart container, 30% blank+ammo+8 coins
- Item multipliers (damage, fire rate, move speed) live on the Player and are read by guns; Run snapshot stores item ids
- Bullet and Enemy scripts must not name each other's class (circular load): Bullet uses duck typing
- Never share shape resources between nodes
- Autoloads (`Run`) are not visible by name in headless test scripts: look up with root.get_node("Run"); scripts that must also compile there use get_node_or_null
- Testing: Godot headless `--script` tests extend SceneTree (22 suites, all passing; kept outside the repo); redirect output to a file, wait for process frames for HUD checks
- Known rough edges: beam damage numbers spam each tick; boss has the same stats on every floor; player starts with all 10 guns; HUD does not show owned items yet; run restarts immediately after victory or death until the hub exists
- `SaveData` (autoload) is the PERMANENT save (currency, unlocks, stats, settings); `Run` is the temporary run state. Add a new saved value by adding a key to SaveData.DEFAULTS; bump VERSION and fill _migrate() if a format ever changes
- A new unlock = an UnlockData .tres in unlocks/data/ pointing at a gun (file name in weapons/data/) or an item id; without an entry a gun/item is free from the start. Dev switch: run the game or tests with `-- --unlock-all`; the older test suites need it, test_unlocks must run without it
