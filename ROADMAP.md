# Gungeon Massive Ripoff Edition: roadmap and status

Full version lives in the repo as ROADMAP.md. Godot 4.7.2, GDScript, placeholder shapes for art (all visuals under a `Visual` node). Code layout: entities/, weapons/, levels/, ui/, autoload/.

Working style: small segments, one at a time, each tested and delivered (changed files only) before the next. Push to GitHub only when the user says so.

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

## Next, in order

11b First five passive items \
12a Save system \
12b Permanent currency/unlocks \
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
