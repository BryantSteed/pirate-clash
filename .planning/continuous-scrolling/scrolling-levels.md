# Continuous Scrolling Levels (Mario-style)

How to build levels larger than the screen, where the view follows the player, in Godot 4.5.

---

## The core idea

**The world doesn't move; the camera does.**

Build each level as **one scene that is much bigger than the screen**, and attach a `Camera2D` to the player. The camera decides which part of the world is shown, and Godot only renders what's inside the view. You don't write a loop that walks the map and draws the visible part.

Web analogy: the level is a very large page, the screen is the browser viewport, and `Camera2D` is the scroll position, scrolled automatically to follow the player.

```
PirateCave (Node2D)                 ← one level = one scene, as big as you like
├── ParallaxBackground (Parallax2D) ← distant cave wall, scrolls slower than the world
│   └── Sprite2D
├── Terrain (TileMapLayer)          ← ground/walls/platforms: the level's "map in memory"
├── Decor (TileMapLayer)            ← non-colliding decoration drawn on top
├── Crystals (Node2D)               ← crystal.tscn instances, anywhere in the world
├── Pirates (Node2D)                ← pirate.tscn instances
├── Player (CharacterBody2D)
│   └── Camera2D                    ← follows the player automatically (it's a child)
└── HUD (CanvasLayer)               ← fixed on screen; ignores the camera
    └── CrystalCounter (Label)
```

This replaces screen-size checks (like the early `display_vec` floor check). Boundaries become real collision (tiles), and the camera's **limits** stop it from showing past the level's edges.

### Where this fits with scene switching
- **`change_scene_to_*`** is still used for big transitions: title → explanation → level 1 → level 2 → game over.
- **Within a level**, nothing is swapped. The whole level scene is loaded, and the camera moves over it.
- Streaming chunks of the map in and out is only needed for very large or endless or procedural worlds. For hand-built levels, one scene per level is the standard.

---

## Classes at play

| Class | Kind | Role |
|---|---|---|
| `Camera2D` | Node | The "screen": which part of the world is visible |
| `TileMapLayer` | Node | A grid of tiles: level geometry, drawing and collision |
| `TileSet` | Resource | The palette: which tiles exist and their properties |
| `TileSetAtlasSource` | Resource | A spritesheet sliced into tiles (inside a TileSet) |
| `TileSetScenesCollectionSource` | Resource | "Tiles" that instance scenes (inside a TileSet) |
| `TileData` | Object | One tile's definition: collision, custom data, modulate… |
| `Parallax2D` | Node | Background layers that scroll slower or faster than the world |
| `CanvasLayer` | Node | HUD/UI that stays fixed on screen |
| `VisibleOnScreenNotifier2D` / `VisibleOnScreenEnabler2D` | Node | React to or pause things when they're off-screen |

---

## Camera2D

A node that sets which part of the world the viewport shows. Only one camera per viewport is active at a time (the "current" one).

### How following works
Make it a **child of the player**. Children inherit their parent's transform, so the camera moves with the player automatically. No code is needed.

### Key properties
| Property | What it does |
|---|---|
| `enabled` | Whether this camera can become the current one |
| `make_current()` | Switch to this camera (if you have several) |
| `anchor_mode` | `DRAG_CENTER` (default): the camera's position is the **center** of the screen |
| `zoom` | `Vector2(2, 2)` = zoomed in 2× (shows less of the world) |
| `offset` | Shift the view without moving the node (e.g. look ahead or screen shake) |
| `position_smoothing_enabled` / `_speed` | Ease toward the target instead of snapping |
| `limit_left` / `limit_top` / `limit_right` / `limit_bottom` | Pixel bounds the view never shows past (world edges) |
| `limit_smoothed` | Ease into limits instead of hard-stopping |
| `drag_horizontal_enabled` / `drag_vertical_enabled` + `drag_*_margin` | A "dead zone": the player can move within it before the camera follows |
| `process_callback` | `IDLE` or `PHYSICS`: when the camera updates (see jitter below) |

### Typical platformer setup
- `position_smoothing_enabled = true`, speed around 5–8.
- `drag_vertical_enabled = true` with top/bottom margins around 0.2–0.3. Small jumps don't jerk the camera up and down; it follows vertically only on real height changes.
- Limits set to the level's bounds (computed from the tilemap; see below).

### Setting limits from the tilemap
```gdscript
# pirate_cave.gd (the level sets up its own camera bounds)
@onready var terrain: TileMapLayer = $Terrain
@onready var camera: Camera2D = $Player/Camera2D

func _ready() -> void:
	var rect := terrain.get_used_rect()            # painted area, in cells
	var tile := terrain.tile_set.tile_size         # cell size, in pixels
	var origin := terrain.global_position
	camera.limit_left   = int(origin.x) + rect.position.x * tile.x
	camera.limit_top    = int(origin.y) + rect.position.y * tile.y
	camera.limit_right  = int(origin.x) + rect.end.x * tile.x
	camera.limit_bottom = int(origin.y) + rect.end.y * tile.y
```

### Jitter
The player moves in `_physics_process` (60 Hz), but frames may render at 144 Hz. If the camera looks stuttery:
- Turn on **Physics Interpolation** (Project Settings → Physics → Common) so rendering smooths between physics ticks, **or**
- Set the camera's `process_callback = PHYSICS`.

---

## TileMapLayer

A single node that stores a **grid of cells** and draws them. It's the standard way to build 2D level geometry.

### What each cell stores
Exactly three values per painted cell. **This is fixed and not extensible:**
```
coords (Vector2i) → source_id (which atlas), atlas_coords (which tile in it), alternative_tile (which variant)
```
The whole grid is saved in the scene as a packed byte array (`tile_map_data`).

### Tiles are data, not nodes (the flyweight pattern)
- A tile's image, collision and properties are defined **once** in the TileSet. Cells only point to them.
- 10,000 ground cells are 10,000 table entries, **not** 10,000 nodes.
- **Rendering:** cells are grouped into chunks (rendering quadrants, 16×16 cells by default), and each chunk is one batched draw on the `RenderingServer`. There are no `Sprite2D`s.
- **Collision:** the layer creates static bodies **directly on the `PhysicsServer2D`** and attaches each solid tile's shape. The result is the same as `StaticBody2D`s, but with no nodes in the tree. (A `StaticBody2D` node is just a wrapper that does this registration for you.)
- **Exception:** scene tiles (from a `TileSetScenesCollectionSource`) **do** instance real nodes.

### Using multiple layers
Use one `TileMapLayer` node per layer, all sharing the same TileSet:
- `Background`: cave wall art, no collision
- `Terrain`: ground/platforms, **with** collision
- `Decor`: rocks, torches, drawn over terrain

Draw order follows tree order (later siblings draw on top), or use `z_index`.

### Key properties
| Property | Meaning |
|---|---|
| `tile_set` | The TileSet resource (the palette) |
| `enabled` | Turn the whole layer off |
| `collision_enabled` | Whether this layer creates physics bodies |
| `use_kinematic_bodies` | Makes tile bodies kinematic (for moving tilemaps) |
| `y_sort_enabled` | Sort by Y (mostly top-down games) |
| `rendering_quadrant_size` | Chunk size for batched drawing |

### Code API
```gdscript
@onready var terrain: TileMapLayer = $Terrain

terrain.set_cell(Vector2i(10, 5), 0, Vector2i(2, 0))   # place: cell, source_id, atlas_coords[, alternative]
terrain.erase_cell(Vector2i(10, 5))                    # remove (visual AND collision)
terrain.get_cell_source_id(Vector2i(10, 5))            # -1 = empty
terrain.get_cell_atlas_coords(Vector2i(10, 5))
terrain.get_cell_tile_data(Vector2i(10, 5))            # → TileData (custom data etc.) or null

terrain.get_used_cells()                  # Array[Vector2i] of all painted cells
terrain.get_used_rect()                   # bounding Rect2i, in cells

terrain.local_to_map(local_pos)           # pixel (layer-local) → cell
terrain.map_to_local(cell)                # cell → pixel (the cell's CENTER, layer-local)
terrain.to_local(global_pos)              # use first when you have a global position

terrain.get_surrounding_cells(cell)       # neighbors
terrain.clear()                           # erase everything
```

### Identifying which tile you hit
Collisions report the **TileMapLayer node** as the collider. To find the exact cell, use the body RID:
```gdscript
# In a CharacterBody2D after move_and_slide():
for i in get_slide_collision_count():
	var hit := get_slide_collision(i)
	var layer := hit.get_collider() as TileMapLayer
	if layer:
		var cell := layer.get_coords_for_body_rid(hit.get_collider_rid())
		var data := layer.get_cell_tile_data(cell)
		if data and data.get_custom_data("is_hazard"):
			hit()
```
Area2Ds (bullets, crystals) get the TileMapLayer as `body` in `body_entered(body)`. Use `body_shape_entered(body_rid, body, ...)` to get the RID and so the cell.

### Building a level from data
`set_cell` lets you build or modify the map from in-memory data (an array, text file, JSON) at load time:
```gdscript
const MAP := [
	"...........................",
	"........###.......###......",
	"...............#...........",
	"###########################",
]

func build(layer: TileMapLayer) -> void:
	layer.clear()
	for y in MAP.size():
		for x in MAP[y].length():
			if MAP[y][x] == "#":
				layer.set_cell(Vector2i(x, y), 0, Vector2i(0, 0))
```
Painting in the editor is usually faster for hand-built levels; generating from data suits procedural levels or a custom level format.

---

## TileSet (the palette)

A **resource** (data, not a node) assigned to a TileMapLayer's `tile_set`. It can be embedded in the scene or saved as its own `.tres` file so several levels share it. **Save it as a file** once it's shared across levels.

### What it defines
| Section | Purpose |
|---|---|
| `tile_size` | Pixel size of every cell (e.g. 16×16, 32×32) |
| **Sources** | Where tiles come from: atlas (image) or scene collection |
| **Physics Layers** | Collision shapes per tile, plus collision layer/mask/material |
| **Terrain Sets** | Autotiling: paint "ground" and edge/corner tiles are chosen automatically |
| **Custom Data Layers** | Your own typed fields per tile (bool, int, float, String, Resource…) |
| Navigation / Occlusion layers | Pathfinding meshes / light occluders per tile |

### TileSetAtlasSource
A spritesheet sliced into a grid of tiles. Each tile within it is addressed by `atlas_coords` (e.g. `(2, 0)` = third column, first row). Tiles can span multiple cells (`size_in_atlas`) and have **alternative tiles**: flipped or rotated or recolored variants, or copies with different custom data.

### TileSetScenesCollectionSource
"Tiles" that instance a **scene** at the cell. Useful for painting crystals or pirates onto the grid. Each placed one is a real node with scripts and signals.

### TileData
The definition of one tile (atlas tile + alternative). Read it at runtime via `layer.get_cell_tile_data(cell)`:
```gdscript
data.get_custom_data("is_hazard")
data.modulate
data.get_collision_polygons_count(0)
```

---

## Extending per-tile and per-cell data

Cells can't hold extra fields, so extensibility lives elsewhere:

| Need | Approach |
|---|---|
| All tiles of type X behave the same | **Custom data layer** on the TileSet |
| A few fixed variants of one tile | **Alternative tiles** (each can have its own custom data) |
| Per-cell state that changes at runtime | **Side dictionary** keyed by `Vector2i` on a `TileMapLayer` subclass |
| Changing a few cells' visuals or collision at runtime | `_use_tile_data_runtime_update` + `_tile_data_runtime_update` |
| The "tile" needs a script, AI or animation | **Scene tile** or a regular scene instance |

### Side-dictionary example (breakable blocks)
```gdscript
# breakable_terrain.gd
extends TileMapLayer

var damage: Dictionary[Vector2i, int] = {}

func hit_cell(cell: Vector2i) -> void:
	var data := get_cell_tile_data(cell)
	if data == null or not data.get_custom_data("breakable"):
		return
	damage[cell] = damage.get(cell, 0) + 1
	if damage[cell] >= data.get_custom_data("hit_points"):
		erase_cell(cell)
		damage.erase(cell)
```

### Runtime per-cell override example
```gdscript
extends TileMapLayer

var cracked: Dictionary[Vector2i, bool] = {}

func _use_tile_data_runtime_update(coords: Vector2i) -> bool:
	return cracked.has(coords)

func _tile_data_runtime_update(coords: Vector2i, tile_data: TileData) -> void:
	tile_data.modulate = Color(1, 0.6, 0.6)    # modifying a per-cell COPY

func crack(coords: Vector2i) -> void:
	cracked[coords] = true
	notify_runtime_tile_data_update()
```
Keep the number of overridden cells small; this path is slower than normal tiles.

---

## Parallax2D: background depth

A node (Godot 4.3+, replacing `ParallaxBackground`/`ParallaxLayer`) whose children scroll at a different rate than the camera. This produces the classic depth effect.

| Property | Meaning |
|---|---|
| `scroll_scale` | `(0.5, 0.5)` = moves at half the camera's speed (appears far away); `(1, 1)` = moves with the world |
| `repeat_size` | Tile the child infinitely every N pixels (set to the texture's width for an endless background) |
| `repeat_times` | How many copies to draw (increase if gaps appear when zoomed out) |
| `autoscroll` | Constant drift in px/s (clouds, water) |
| `scroll_offset` | Starting offset |

```
ParallaxFar (Parallax2D)    scroll_scale = (0.2, 0.2), repeat_size = (1152, 0)
└── Sprite2D                (Crystal Cove Background.png, centered = false)
ParallaxNear (Parallax2D)   scroll_scale = (0.6, 0.6)
└── Sprite2D                (closer rocks)
```
Put parallax nodes **first** in the level so they draw behind everything.

---

## CanvasLayer: the fixed HUD

Anything that must stay on screen while the camera scrolls (crystal counter, health, pause menu) goes under a `CanvasLayer` with `layer = 1` or higher. It has its own transform that the camera doesn't affect. Controls inside it can use anchors (e.g. top-left) against the screen.

```gdscript
# hud.gd: listens for game events, never reaches into the level
func update_crystals(count: int) -> void:
	$CrystalCounter.text = "Crystals: %d" % count
```

---

## Off-screen handling

With a big level, many things live off-screen. Two helper nodes:

| Node | Use |
|---|---|
| `VisibleOnScreenNotifier2D` | Emits `screen_entered` / `screen_exited`. E.g. free bullets that leave the screen, or start a pirate's shoot timer only when visible |
| `VisibleOnScreenEnabler2D` | Automatically **pauses** a target node's processing while off-screen (`enable_node_path`, `enable_mode`) |

For pirate-clash: pirates shouldn't shoot at the player from across the level. Either give each pirate a `VisibleOnScreenEnabler2D`, or gate `_shoot()` on `screen_entered`/`screen_exited`, or on distance or line of sight.

---

## Setup workflow

1. **Choose the resolution first** (Project Settings → Display → Window → Size + Stretch). Tile size only makes sense relative to it. Pixel art: e.g. 480×270 or 640×360 viewport, stretch mode `viewport`, and **Rendering → Textures → Default Texture Filter = Nearest**.
2. **Export a tileset PNG** from Aseprite (File → Export Sprite Sheet), with tiles on a grid matching your tile size. For prototyping, a PNG of a few solid-colored squares is enough.
3. In the level: add a **`TileMapLayer`** named `Terrain` → Inspector: **Tile Set → New TileSet** → set **Tile Size**.
4. Bottom panel **TileSet** tab → drag the PNG into Tiles → **Yes** to auto-create tiles.
5. TileSet Inspector → **Physics Layers → Add Element**. In the TileSet tab → **Paint → Physics Layer 0**, then click solid tiles.
6. (Optional) **Custom Data Layers** (e.g. `is_hazard: bool`), then paint values.
7. Bottom panel **TileMap** tab → paint the level (pencil, line, rect, bucket; right-click erases).
8. Save the TileSet as a `.tres` (Inspector → Tile Set dropdown → Save As) so every level shares it.
9. Add **`Camera2D`** as a child of the Player (in `player.tscn`) → enable smoothing and vertical drag.
10. Set camera limits from `get_used_rect()` in the level script.
11. Move the crystal counter and other UI into a **`CanvasLayer`** HUD.
12. Add a **`Parallax2D`** background (the Crystal Cove Background art).
13. Debug → **Visible Collision Shapes** to check tile collision.

---

## Plan for pirate-clash

### Changes to existing scenes
- **`levels/pirate_cave/pirate_cave.tscn`**
  - Root `Node` → **`Node2D`** (so world children share a 2D transform).
  - Replace the `Floor` StaticBody2D with a **`Terrain` TileMapLayer**. `objects/floor/` can then be removed.
  - Replace the full-screen background `ColorRect` with a **`Parallax2D`** background (a full-rect ColorRect doesn't scroll with the world, so it only covers the first screen).
  - Group crystals and pirates under `Crystals` / `Pirates` Node2Ds for tidiness (groups still do the lookup).
  - Add a **`HUD` CanvasLayer**.
  - In `pirate_cave.gd`, set camera limits from `Terrain.get_used_rect()`.
- **`player/player.tscn`**: add a **`Camera2D`** child.
- **`objects/pirate/`**: pause or gate shooting while off-screen.

### Suggested new files
```
res://
├── tilesets/
│   ├── cave_tiles.png         (exported from Aseprite)
│   └── cave_tileset.tres      (shared TileSet)
└── ui/
    └── hud/ (hud.tscn, hud.gd)
```

---

## Gotchas checklist

- [ ] Camera2D is a **child of the player** (or follows it in code). Only one camera is current.
- [ ] Camera limits are set, or the view shows empty space past the level's edges.
- [ ] Full-screen `ColorRect` backgrounds replaced; they don't cover a scrolling world.
- [ ] HUD elements are under a **CanvasLayer**, or they'll scroll away.
- [ ] Anything using "screen size" for gameplay (like the old `display_vec`) is replaced by tiles or camera limits.
- [ ] `map_to_local` returns the cell **center**, in **layer-local** coords. Convert with `to_global` / `to_local`.
- [ ] Texture filter is **Nearest** for pixel art, or tiles look blurry.
- [ ] TileSet saved as a `.tres` if shared across levels (otherwise each level has its own copy).
- [ ] Tile collision set up in the TileSet's **physics layer** (painted per tile), with the correct collision layer/mask.
- [ ] Bullets and Area2Ds hitting tiles receive the **TileMapLayer** as `body`, not an individual tile.
- [ ] Off-screen pirates don't shoot across the whole level.
- [ ] Jitter: enable Physics Interpolation, or set the camera's `process_callback = PHYSICS`.
