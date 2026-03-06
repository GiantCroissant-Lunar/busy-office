# RFC-003: Office Simulation & Tile Grid

- **Status**: Draft
- **Created**: 2025-03-06

## Summary

Define the tile-based office environment: grid structure, furniture placement, agent pathfinding, seat assignment, and the agent finite state machine.

## Tile Grid

### Dimensions

- Default office: 24x16 tiles (384x256 pixels at 16px/tile)
- Maximum: 64x64 tiles (expandable for office upgrades in tycoon mode)
- Tile size: 16x16 pixels

### Tile Types

```csharp
public enum TileType : byte
{
    Void = 0,     // Outside office bounds
    Floor = 1,    // Walkable floor
    Wall = 2,     // Impassable wall
}
```

The grid is a flat `TileType[]` array (`width * height`), indexed as `grid[y * width + x]`.

### Walkability

A tile is walkable if:
- `TileType == Floor`
- No furniture entity occupies the tile (except chairs, which are walkable for the assigned agent)

Walkability is cached in a `bool[]` array, rebuilt when furniture changes.

### Initial Office Layout

```
WWWWWWWWWWWWWWWWWWWWWWWW
W......................W
W..DC..DC..DC..DC......W
W......................W
W..DC..DC..DC..DC......W
W......................W
W..........BB..PP..CC..W
W......................W
W..DC..DC..DC..DC......W
W......................W
W..DC..DC..DC..DC......W
W......................W
W..........WB..........W
W......................W
W......................W
WWWWWWWWWWWWWWWWWWWWWWWW

D=Desk, C=Chair, B=Bookshelf, P=Plant, CC=Cooler, WB=Whiteboard
```

16 desk+chair pairs = 16 agent seats. Layout stored as a JSON file (`res://data/office_layout.json`) for easy editing.

### Office Layout Format

```json
{
  "width": 24,
  "height": 16,
  "tiles": "WWW...FFF...WWW...",
  "furniture": [
    { "type": "Desk", "x": 3, "y": 2, "rotation": 0 },
    { "type": "Chair", "x": 4, "y": 2, "rotation": 0 },
    ...
  ]
}
```

`tiles` is a flat string where `W`=Wall, `F`/`.`=Floor, `V`=Void. Length = width * height.

## Pathfinding

### Algorithm: BFS

BFS (Breadth-First Search) is appropriate because:
- All moves cost 1 (uniform grid, no diagonal movement)
- BFS guarantees shortest path on uniform-cost grids
- Grid is small (max 64x64 = 4096 tiles) — BFS is fast enough
- No need for A* overhead or heuristics

### Implementation

```csharp
public class TileMap
{
    private readonly int _width;
    private readonly int _height;
    private readonly TileType[] _tiles;
    private readonly bool[] _walkable;

    public List<Vector2I>? FindPath(Vector2I from, Vector2I to)
    {
        // BFS with 4-directional neighbors (no diagonals)
        // Returns null if no path exists
        // Returns empty list if from == to
    }

    public void RebuildWalkability(IWorld world) { ... }
}
```

### Movement Directions

4-directional only (no diagonals). Matches pixel-art aesthetic where characters face cardinal directions.

```
    Up (0,-1)
Left (-1,0)  Right (+1,0)
   Down (0,+1)
```

### Path Cache

Paths are stored in a `PathCache` to avoid re-allocating lists every frame:

```csharp
public class PathCache
{
    private readonly List<Vector2I[]> _paths = new();

    public int Store(List<Vector2I> path) { ... }   // Returns PathId
    public ReadOnlySpan<Vector2I> Get(int pathId) { ... }
    public void Release(int pathId) { ... }          // Mark for reuse
}
```

## Seat Assignment

### Seat Discovery

A "seat" is a Chair furniture entity adjacent to a Desk entity. On office load:
1. Find all Chair entities
2. For each Chair, find adjacent Desk (4-directional check)
3. Create seat record: `(chairEntity, deskEntity, chairPos, facingDirection)`

`facingDirection` is determined by the desk-to-chair vector (agent faces the desk).

### Assignment Algorithm

When spawning an agent:
1. Find all unassigned seats
2. Pick one (random in tycoon mode, or based on A2A agent order in connected mode)
3. Add `SeatAssignment { SeatEntityId, DeskEntityId }` component to agent entity

## Agent Finite State Machine

### States

```
+-------+     task      +--------+   arrive   +---------+  settle  +--------+
| IDLE  |-------------->| WALKING|------------>| SITTING |--------->| TYPING |
+-------+               +--------+            +---------+          +--------+
    ^                       |                                          |
    |   arrive (random)     |                                          |
    +-----------------------+                        task done         |
    ^                                                                  |
    +------------------------------------------------------------------+
```

### State Details

| State | Entry Condition | Behavior | Exit Condition |
|-------|----------------|----------|----------------|
| **Idle** | Initial state, or task complete | Stand at current position. After 2-5s random timer, wander to random walkable tile. | Task assigned → Walking. Wander timer → Walking (random). |
| **Walking** | Path computed | Follow path tile-by-tile. Speed: 2 tiles/sec default. | Arrive at desk → Sitting. Arrive at random tile → Idle. |
| **Sitting** | Arrived at assigned chair | Brief settle animation (0.3s). | Settle timer done → Typing or Reading (based on task type). |
| **Typing** | Has task, task type is write/code/review | Typing animation. `CurrentTask.Progress` advances. | `Progress >= 1.0` → Idle (task complete). |
| **Reading** | Has task, task type is research/read | Reading animation. `CurrentTask.Progress` advances. | `Progress >= 1.0` → Idle (task complete). |
| **Meeting** | Future: multi-agent collaboration | At whiteboard with other agents. | Meeting duration expires → Walking (back to desk). |

### Wander Behavior (Idle)

When idle with no task:
1. Wait 2-5 seconds (random)
2. Pick a random walkable tile within 8 tiles of current position
3. Walk there
4. Return to idle on arrival
5. Repeat until a task is assigned

This creates natural-looking office movement even without tasks.

### Animation Mapping

| AgentState | Animation | Frames |
|------------|-----------|--------|
| Idle | Standing still | 1 (static) |
| Walking | Walk cycle | 4 (1-2-3-2 pattern) |
| Sitting | Seated | 1 (static) |
| Typing | Typing at desk | 2 (alternating) |
| Reading | Reading at desk | 2 (alternating) |

Sprite direction (Down/Left/Right/Up) determined by `FacingDirection` component. Walk direction updates each tile step.

## Pixel Interpolation

Agents move on a tile grid but render at sub-tile pixel positions for smooth movement:

```
PixelPosition.X = GridPosition.X * 16 + offset_x
PixelPosition.Y = GridPosition.Y * 16 + offset_y
```

During walking, `offset_x`/`offset_y` interpolate linearly from current tile center to next tile center based on `MoveSpeed` and elapsed time. `MovementSystem` handles this.

When not walking, `PixelPosition` snaps to tile center (`GridPosition * 16 + 8`).

## Rendering Layers (Z-Order)

GDScript viewport renders in this order (back to front):
1. Floor tiles
2. Wall tiles
3. Furniture (sorted by Y position)
4. Agents (sorted by Y position)
5. Selection highlight
6. UI overlays (speech bubbles, task progress bars)

## Open Questions

1. **Diagonal movement** — Current design is 4-directional. Could add 8-directional later if it looks better, but sprites would need diagonal frames.

2. **Collision** — Agents currently clip through each other. Add agent-agent collision avoidance? Or acceptable for pixel art style?

3. **Room segmentation** — Should the office have rooms/doors, or one open floor? Start open, add rooms as tycoon upgrade?

## Related RFCs

- [RFC-002](./RFC-002-ecs-integration.md) — Component definitions, system execution
- [RFC-004](./RFC-004-game-bridge.md) — How simulation state reaches the GDScript renderer
- [RFC-006](./RFC-006-tycoon-mode.md) — Task generation that drives agent behavior
