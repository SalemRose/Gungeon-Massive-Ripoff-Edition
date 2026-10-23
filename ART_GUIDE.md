# Art swap guide

Every visible thing is a placeholder shape. This lists each one, where it lives and what to replace it with. Drop the finished files into the matching `assets/` folder first (the folder layout is yours; the suggestions below use it).

## The rule

Everything visible lives under a node called `Visual`. To add art to a scene:

1. Open the scene, expand `Visual`.
2. Delete the placeholder `Polygon2D` children.
3. Add a `Sprite2D` (one picture) or `AnimatedSprite2D` (frames) under `Visual` and assign your texture.
4. Do NOT change collision shapes unless the sprite is much bigger or smaller than the placeholder (sizes below). Do not rename `Visual`: scripts rotate, flip, scale and tint it (hit flashes, the dodge-roll squash, the death fade).

Pixel art: in Project Settings -> Rendering -> Textures set the default filter to `Nearest`, and keep sprites at the sizes below or whole multiples of them.

## Placeholder sizes (pixels, centred on the node origin)

| Thing | Scene -> node | Placeholder | Suggested folder |
|---|---|---|---|
| Player body | `entities/player/player.tscn` -> Visual/Body (+ Marker, a facing dot) | 19x19, collision circle r 8 | `assets/CHARACTERS/PC` |
| Player gun | player.tscn -> AimPivot/GunPlaceholder, Muzzle/Flash | gun 14x4, flash 13x8 | `assets/ITEMS/WEAPONS` |
| Basic enemy | `entities/enemies/enemy.tscn` -> Visual/Body, EyeLeft, EyeRight | 19x19, circle r 9 | `assets/CHARACTERS/ENEMIES` |
| Bullet Kin, Shotgun Kin, Spiral Mage | inherit enemy.tscn (set Visual in each inherited scene) | same as enemy | `assets/CHARACTERS/ENEMIES` |
| Ring Turret | `ring_turret.tscn` | circle r 13 | `assets/CHARACTERS/ENEMIES` |
| The Warden (boss) | `entities/enemies/bosses/warden.tscn` | circle r 22 | `assets/CHARACTERS/ENEMIES` |
| Training dummy | `training_dummy.tscn` | 27x27 | `assets/CHARACTERS/ENEMIES` |
| Player bullet | `entities/projectiles/bullet.tscn` -> Visual | 9x5 | `assets/ITEMS/WEAPONS` |
| Enemy bullet | `entities/projectiles/enemy_bullet.tscn` -> Visual | 8x8 | `assets/ITEMS/WEAPONS` |
| Pickups (heart, ammo, blank, coin, heart container) | `entities/pickups/pickup.tscn`; icons come from `Pickup.make_icon()` in `pickup.gd` | ~12x12 | `assets/ITEMS/CONSUMABLES` |
| Chest | `levels/props/chest.tscn` -> Visual/Body, Lid | body 28x12, lid 30x7 | `assets/SPACES/ARENA` |
| Shop / item pedestal | `shop_item.tscn`, `item_pedestal.tscn` -> Visual/Pedestal | 28x10 | `assets/SPACES/ARENA` |
| Stairs | `levels/props/stairs.tscn` -> Visual/Step1-3 | 40x32 | `assets/SPACES/ARENA` |
| Table (flippable) | `levels/props/table.tscn` -> Visual | about 40x24 | `assets/SPACES/ARENA` |
| Door | `levels/rooms/door.tscn` -> Visual/Slab | 48x16 | `assets/SPACES/ARENA` |
| Pillar | `levels/rooms/pillar.tscn` -> Visual/Block | 32x32 | `assets/SPACES/ARENA` |
| Hub terminal and dungeon door | built in code: `levels/hub/hub_station.gd` (`Visual` node) | 36x36 | `assets/SPACES/LOBBY` |

## Things set by data (no scene editing)

- **Passive items**: `items/data/*.tres` -> `icon` (Texture2D). `icon_color` is only the placeholder diamond. Used on pedestals; the item pedestal draws the texture when set.
- **Guns**: `weapons/data/*.tres` -> `color` is the placeholder bullet/gun tint. A gun icon/sprite field does not exist yet; add `@export var icon: Texture2D` to `weapon_data.gd` when you have gun art (the HUD currently shows text).
- **Unlocks**: `unlocks/data/*.tres` have no icon yet (the shop is text rows).

## Built from code (bigger jobs)

- **Room floors, walls and corridors**: `levels/rooms/room.gd` and `corridor.gd` draw colored `Polygon2D` rectangles (`wall_color`, floor colour exports). The proper fix is a `TileMapLayer` with a tileset in `assets/SPACES/ARENA`; ask for this as its own step when the tileset exists.
- **Hub room**: `levels/hub/hub.gd` (`_build_room`), same idea (`assets/SPACES/LOBBY`).
- **HUD, menus, shop, pause, settings**: plain Godot `Control` nodes built in `ui/hud/hud.tscn` and `ui/menu/*.gd`, `ui/hub/unlock_shop.gd`. Restyle them with a single `Theme` resource (fonts, button styles, colours) assigned to the root Control / CanvasLayer children; put textures in `assets/INTERFACE/HUD` and `assets/INTERFACE/MENUS`.
- **Minimap** (`ui/hud/minimap.gd`) and **boss bar** (`boss_bar.gd`) are drawn in code.

## Sound

No audio exists yet. When it does, set each `AudioStreamPlayer`'s `bus` to `Music` or `SFX` so the settings sliders control it.
