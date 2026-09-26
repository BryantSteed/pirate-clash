# Godot 2D Physics Nodes: Gravity, Bodies & Collision

Reference notes for implementing jump-based movement in pirate-clash (Godot 4.5).

---

## The big picture

A physics object in Godot is always **two things together**:

1. A **body** node: the physics object itself (how it moves and what it is)
2. One or more **shape** children: its geometry (how much space it occupies)

Visuals (ColorRect, Sprite2D) are separate again. They're only drawn and have no effect on collisions.

```
Player (CharacterBody2D)      ← the physics object: velocity, move_and_slide()
├── CollisionShape2D          ← its hitbox (holds a RectangleShape2D resource)
└── ColorRect / Sprite2D      ← what it looks like (purely visual)
```

| Node | Moves how? | Blocks things? | Use for |
|---|---|---|---|
| `CharacterBody2D` | You set `velocity` in code | Yes | Player, enemies |
| `StaticBody2D` | Doesn't move | Yes | Floors, walls, platforms |
| `AnimatableBody2D` | Moved by code/animation, pushes others | Yes | Moving platforms, doors |
| `RigidBody2D` | Physics simulation (forces, bounce) | Yes | Crates, cannonballs, debris |
| `Area2D` | Doesn't block; only detects overlaps | No | Pickups (crystals), hazards, triggers |
| `TileMapLayer` | Static tile grid | Yes (per-tile shapes) | Building whole levels |

---

## CharacterBody2D: the player

A body **you** control. You decide the `velocity`, and the engine moves it and resolves collisions (stopping at walls, sliding along floors, handling slopes).

Use it for the player and enemies instead of `RigidBody2D`. Rigid bodies are driven by the simulation, which makes controls feel floaty and hard to tune.

### Key properties
| Property | Meaning |
|---|---|
| `velocity: Vector2` | Pixels per second. Set this, then call `move_and_slide()` |
| `up_direction` | Which way is "up" for floor detection (default `Vector2.UP`) |
| `motion_mode` | `GROUNDED` (platformer: floors/walls/ceilings) or `FLOATING` (top-down) |
| `floor_max_angle` | Steepest slope that still counts as floor |
| `floor_snap_length` | Keeps you glued to the floor going down slopes |

### Key methods
| Method | Meaning |
|---|---|
| `move_and_slide() -> bool` | Moves by `velocity * delta` (delta is applied for you), slides along collisions, updates floor/wall state. Returns true if it collided |
| `is_on_floor()` / `is_on_wall()` / `is_on_ceiling()` | Contact state from the **last** `move_and_slide()` |
| `get_gravity() -> Vector2` | Gravity at this body's position (project default, or an Area2D override) |
| `get_slide_collision_count()` / `get_slide_collision(i)` | What you hit this tick (`KinematicCollision2D`) |
| `move_and_collide(motion)` | Lower-level: moves once, stops at the first hit, returns the collision |

### Basic platformer movement
Attach a script and choose the **"CharacterBody2D: Basic Movement"** template to get something like this:

```gdscript
extends CharacterBody2D

const SPEED := 300.0
const JUMP_VELOCITY := -400.0     # negative = up (y grows downward in 2D)

func _physics_process(delta: float) -> void:
	# Gravity is ACCELERATION: it changes velocity, and velocity changes position.
	if not is_on_floor():
		velocity += get_gravity() * delta

	if Input.is_action_just_pressed("up") and is_on_floor():
		velocity.y = JUMP_VELOCITY

	var direction := Input.get_axis("left", "right")
	if direction:
		velocity.x = direction * SPEED
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)

	move_and_slide()
```

Notes:
- Always run movement in `_physics_process` (fixed 60 Hz tick), not `_process`.
- Don't multiply `velocity` by `delta` before `move_and_slide()`; it does that internally. *Do* multiply the **gravity acceleration** by `delta` when adding it to velocity.
- Gravity comes from **Project Settings → Physics → 2D → Default Gravity** (980 px/s² by default), so every body falls consistently.

---

## CollisionShape2D: the hitbox

A node that gives its **direct parent** body a shape. It registers itself with the parent automatically when it enters the tree. No wiring is needed.

### Rules
- **Must be a direct child** of a body/area. `Player → Node2D → CollisionShape2D` won't register (the editor shows ⚠️).
- A body with no shape collides with nothing (⚠️), and a shape with no body does nothing (⚠️).
- A body can have **several** shapes; together they act as one combined hitbox.
- `disabled = true` turns it off. Inside physics callbacks, use `set_deferred("disabled", true)`, because changing physics state mid-step causes errors.

### Node vs. resource
The shape comes in two layers:

| | `CollisionShape2D` (node) | `Shape2D` (resource) |
|---|---|---|
| Stores | **Where**: position, rotation, scale (relative to parent) | **What**: dimensions only |
| Examples | — | `RectangleShape2D` (`size`), `CircleShape2D` (`radius`), `CapsuleShape2D` (`radius`, `height`), `SegmentShape2D`, `WorldBoundaryShape2D` |
| Set via | Scene dock | The node's **Shape** property in the Inspector |

- The shape is **centered on the node's origin**. A 40×40 `RectangleShape2D` at (0, 0) spans −20…+20.
  - ⚠️ A `ColorRect` starts at its **top-left** (0…40), so they won't line up by default. Either center the ColorRect (offsets −20…20) or move the shape to (20, 20). Centering is the convention.
- **Don't scale** shape nodes (especially non-uniformly); change the resource's `size`/`radius` instead.
- Shapes are invisible in-game. Turn on **Debug → Visible Collision Shapes** while testing.

### CollisionPolygon2D
The alternative to `CollisionShape2D` for irregular outlines: draw the polygon point by point in the editor. Same rules (direct child of a body).

---

## StaticBody2D: floors and walls

A body that never moves on its own. Others collide with it. Give it a shape and a visual:

```
Floor (StaticBody2D)
├── CollisionShape2D    (wide RectangleShape2D, e.g. 1152×40)
└── ColorRect           (visual, centered to match)
```

- `constant_linear_velocity`: makes it act like a **conveyor belt** (things on it get pushed) without it moving.
- For platforms that actually move, use **`AnimatableBody2D`** (move it from code or an AnimationPlayer; it carries characters standing on it).

---

## RigidBody2D: simulated objects

Moved by the physics engine: gravity, forces, bouncing, rotation. You nudge it rather than setting its position.

```gdscript
var ball := CannonballScene.instantiate() as RigidBody2D
ball.global_position = $Muzzle.global_position
get_tree().current_scene.add_child(ball)
ball.apply_central_impulse(Vector2(600, -200))   # a one-time kick
```

| Member | Meaning |
|---|---|
| `mass`, `gravity_scale` | Weight, and how much gravity affects it (0 = floats) |
| `linear_velocity`, `angular_velocity` | Current motion (readable; avoid setting it every frame) |
| `apply_central_impulse(v)` / `apply_impulse(v, offset)` | An instant push |
| `apply_central_force(v)` / `apply_force(v, offset)` | A continuous push (call every tick) |
| `freeze` | Temporarily stop simulating |
| `lock_rotation` | Stop it from spinning |
| `_integrate_forces(state)` | Safe place to directly modify its physics state |
| `physics_material_override` | Bounce and friction |

- ⚠️ Don't set `position` directly on a rigid body each frame; that fights the simulation.
- ⚠️ Its `body_entered` signal only fires if `contact_monitor = true` **and** `max_contacts_reported > 0`.

---

## Area2D: detection zones (crystals!)

Detects overlaps but **doesn't block** anything. Ideal for pickups, hazards, checkpoints and triggers.

```
Crystal (Area2D)
├── CollisionShape2D
└── Sprite2D
```

```gdscript
# crystal.gd
extends Area2D

signal collected

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node2D) -> void:
	if body is Player:              # requires class_name Player in player.gd
		collected.emit()
		queue_free()
```

| Signal / member | Meaning |
|---|---|
| `body_entered(body)` / `body_exited(body)` | A physics body (e.g. the player) started/stopped overlapping |
| `area_entered(area)` / `area_exited(area)` | Another Area2D overlapped |
| `get_overlapping_bodies()` | Everything overlapping right now (polling style) |
| `monitoring` / `monitorable` | Whether it detects others / can be detected |
| `gravity_space_override`, `gravity`, `gravity_direction` | **Overrides gravity inside the area**: water, low-gravity zones, wind. `get_gravity()` on bodies inside picks this up automatically |

---

## TileMapLayer: levels

A grid of tiles from a `TileSet`. Add a **physics layer** to the TileSet and paint collision polygons onto tiles, and every painted tile becomes solid. It's the fastest way to build platforms and cave walls without placing StaticBody2Ds by hand.

---

## Collision layers & masks

Every body and area has two sets of checkboxes (32 layers, which you can name under Project Settings → Layer Names → 2D Physics):

- **Layer**: what I **am**
- **Mask**: what I **look for** / collide with

A collision or detection happens when one object's mask includes the other's layer.

Example setup:

| Object | Layer | Mask |
|---|---|---|
| Player | 1 (player) | 2 (world), 3 (pickups) |
| Floor/walls | 2 (world) | — |
| Crystal (Area2D) | 3 (pickups) | 1 (player) |
| Enemy | 4 (enemies) | 2 (world) |

This makes enemies pass through each other while still landing on the floor, and makes crystals notice only the player.

---

## Making jumps feel good (manual, on top of CharacterBody2D)

The engine gives correct physics, but good game feel is tuned by hand:

```gdscript
const COYOTE_TIME := 0.1       # can still jump shortly after leaving a ledge
const JUMP_BUFFER := 0.1       # a jump pressed just before landing still counts
const FALL_GRAVITY_MULT := 1.8 # falling faster than rising feels snappier

var coyote_timer := 0.0
var buffer_timer := 0.0

func _physics_process(delta: float) -> void:
	var gravity := get_gravity()
	if velocity.y > 0:
		gravity *= FALL_GRAVITY_MULT
	if not is_on_floor():
		velocity += gravity * delta

	coyote_timer = COYOTE_TIME if is_on_floor() else coyote_timer - delta
	buffer_timer = JUMP_BUFFER if Input.is_action_just_pressed("up") else buffer_timer - delta

	if buffer_timer > 0 and coyote_timer > 0:
		velocity.y = JUMP_VELOCITY
		buffer_timer = 0
		coyote_timer = 0

	# Variable jump height: releasing early cuts the jump short
	if Input.is_action_just_released("up") and velocity.y < 0:
		velocity.y *= 0.5

	# ...horizontal movement...
	move_and_slide()
```

---

## Plan for pirate-clash

### Target scene structure
```
PirateCave (Node2D)                 ← change from Node so 2D children share a transform
├── Background (ColorRect)
├── Floor (StaticBody2D)
│   ├── CollisionShape2D
│   └── ColorRect
├── Player (CharacterBody2D)        ← Player.tscn instance
│   ├── CollisionShape2D  (40×40)
│   └── ColorRect         (centered: offsets −20…20)
└── Crystals (Node2D)
    └── Crystal (Area2D) × N        ← crystal.tscn instances
```

### Converting the current Player
1. Open `Player.tscn` → right-click `Player` → **Change Type → CharacterBody2D**.
2. Add a **CollisionShape2D** child → Shape: **New RectangleShape2D** → size 40×40.
3. Center the ColorRect (offsets −20…20) so the visual matches the shape.
4. Replace `player.gd` with the template movement above (`extends CharacterBody2D`, actions `up`/`left`/`right`). The manual `display_vec` floor check is no longer needed.
5. Add `class_name Player` so other scripts (like crystals) can type-check against it.
6. In `pirate_cave.tscn`, change the root to **Node2D** and add a `Floor` StaticBody2D.

---

## Gotchas checklist

- [ ] Body has a `CollisionShape2D` as a **direct** child (no ⚠️ in the Scene dock)
- [ ] Shape and visual are aligned (shape is centered, Controls start top-left)
- [ ] Movement code is in `_physics_process`, not `_process`
- [ ] Gravity is added to **velocity** (× delta), not to position
- [ ] `is_on_floor()` is only valid **after** a `move_and_slide()` call
- [ ] Physics changes inside collision callbacks use `set_deferred` / `call_deferred`
- [ ] Layers/masks are set so the right things collide
- [ ] **Debug → Visible Collision Shapes** turned on while testing
