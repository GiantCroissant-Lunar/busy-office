# RFC-002: ECS Integration & Components

- **Status**: Draft
- **Created**: 2025-03-06

## Summary

Integrate unify-ecs (Arch backend) into the busy-office C# host. Define the ECS component vocabulary, system execution order, and how the ECS world is created and updated within Godot's game loop.

## Dependencies

- unify-ecs packages: `UnifyEcs.Core`, `UnifyEcs.Attributes`, `UnifyEcs.Generators`, `UnifyEcs.Runtime.Arch`
- Packages must be built from `C:\lunar-horse\plate-projects\unify-ecs` and synced to local NuGet feed

## NuGet References

```xml
<!-- complete-app.csproj -->
<PackageReference Include="UnifyEcs.Core" Version="0.1.*" />
<PackageReference Include="UnifyEcs.Attributes" Version="0.1.*" />
<PackageReference Include="UnifyEcs.Generators" Version="0.1.*"
    OutputItemType="Analyzer" ReferenceOutputAssembly="false" />
<PackageReference Include="UnifyEcs.Runtime.Arch" Version="0.1.*" />
```

`UnifyEcs.Generators` is a Roslyn source generator — it must be referenced as an `Analyzer` with `ReferenceOutputAssembly="false"` so it runs at compile time without being deployed.

## Components

All components are value-type structs decorated with `[EcsComponent]`. Grouped by domain:

### Spatial

```csharp
[EcsComponent]
public struct GridPosition { public int X; public int Y; }

[EcsComponent]
public struct PixelPosition { public float X; public float Y; }

[EcsComponent]
public struct FacingDirection { public Direction Value; }
// enum Direction { Down = 0, Left = 1, Right = 2, Up = 3 }
```

`GridPosition` is the authoritative tile coordinate. `PixelPosition` is interpolated for smooth rendering between tiles (16px per tile). `FacingDirection` drives sprite selection.

### Movement

```csharp
[EcsComponent]
public struct PathBuffer
{
    // Fixed-size buffer. MaxLength chosen to cover worst-case BFS
    // on a 64x64 grid (theoretical max ~4096, practical max ~200).
    public int Length;
    public int StepIndex;
    // Path stored externally in TileMap pathfinding cache, referenced by PathId.
    public int PathId;
}

[EcsComponent]
public struct MoveSpeed { public float TilesPerSecond; }
```

Path data is stored in a shared `PathCache` (managed by `TileMap`) rather than inside the component, to avoid large structs in the archetype. `PathId` references the cached path.

### Agent Identity

```csharp
[EcsComponent]
public struct AgentIdentity
{
    public int EntityId;       // Stable ID for bridge references
    public int PaletteIndex;   // Sprite palette (0-5, then hue-shifted)
    public AgentRole Role;     // Coder, Reviewer, TestWriter, DocsWriter, Learner
}
// AgentIdentity.Name stored in a separate lookup (string not suitable for struct)

[EcsComponent]
public struct AgentName { public int NameIndex; }
// Index into GameWorld.AgentNames string table
```

Agent names are stored in a string table (`GameWorld.AgentNames: List<string>`) to avoid managed references in ECS components. `NameIndex` maps to the table.

### Agent State Machine

```csharp
[EcsComponent]
public struct AgentFsm
{
    public AgentState State;
    public float Timer;        // Time remaining in current state
    public AgentState Previous; // For transition logic
}

public enum AgentState
{
    Idle,       // Standing, waiting for task or wander timer
    Walking,    // Moving along path
    Sitting,    // At desk, transitioning to work
    Typing,     // Working — writing code, reviewing
    Reading,    // Working — reading docs, researching
    Meeting,    // At whiteboard or with another agent
}
```

### Tasks

```csharp
[EcsComponent]
public struct CurrentTask
{
    public int TaskId;         // Index into task registry
    public float Progress;     // 0.0 to 1.0
    public float Duration;     // Total seconds to complete
}
```

Task metadata (description, type, reward) stored in a `TaskRegistry` lookup table, same pattern as agent names.

### Office Furniture

```csharp
[EcsComponent]
public struct Furniture
{
    public FurnitureType Type;
    public int Rotation;       // 0, 90, 180, 270
}

public enum FurnitureType
{
    Desk,        // 2x1, has a seat position
    Chair,       // 1x1, marks a seat
    Bookshelf,   // 1x2
    Plant,       // 1x1
    Cooler,      // 1x1
    Whiteboard,  // 2x1
    Pc,          // 1x1, placed on desk
    Lamp,        // 1x1
}
```

### Seat Assignment

```csharp
[EcsComponent]
public struct SeatAssignment
{
    public int SeatEntityId;   // Entity ID of the chair
    public int DeskEntityId;   // Entity ID of the associated desk
}
```

### Sync (Connected Mode)

```csharp
[EcsComponent]
public struct SyncSource
{
    public int A2AAgentIndex;  // Index into A2AWebSocketClient.AgentCards
}

[EcsComponent(IsTag = true)]
public struct ServerDriven { }  // Tag: skip local FSM, driven by WebSocket
```

## Systems

Systems are partial classes with `[EcsSystem]` and `[Query]` attributes. Execution order follows `SystemPhase` + `Order`.

### System Execution Order

| Phase | Order | System | Description |
|-------|-------|--------|-------------|
| EarlyUpdate | 0 | `A2ASyncSystem` | Pull WebSocket events into ECS |
| EarlyUpdate | 10 | `TycoonTaskSystem` | Generate/assign tasks (offline mode) |
| Update | 0 | `AgentFsmSystem` | State machine transitions |
| Update | 10 | `PathfindingSystem` | Compute BFS paths for walking agents |
| Update | 20 | `MovementSystem` | Move agents along paths, interpolate pixels |
| LateUpdate | 0 | `RenderBridgeSystem` | Push ECS state to GameBridge |

### AgentFsmSystem

```
IDLE --[task assigned]--> WALKING (to desk)
IDLE --[wander timer]--> WALKING (random tile)
WALKING --[arrived at desk]--> SITTING
WALKING --[arrived at random]--> IDLE
SITTING --[settle timer]--> TYPING or READING (based on task type)
TYPING/READING --[task complete]--> IDLE
TYPING/READING --[no task, timeout]--> IDLE
MEETING --[meeting over]--> WALKING (back to desk)
```

Agents with `ServerDriven` tag skip local transitions — their state is set by `A2ASyncSystem`.

### PathfindingSystem

- Queries entities with `AgentFsm.State == Walking` and `PathBuffer.Length == 0`
- Calls `TileMap.FindPath(from, to)` using BFS
- Stores result in `PathCache`, sets `PathBuffer.PathId`

### MovementSystem

- Queries entities with `PathBuffer.Length > 0`
- Advances `StepIndex` based on `MoveSpeed` and delta time
- Updates `GridPosition` when reaching next tile
- Interpolates `PixelPosition` between current and next tile
- Updates `FacingDirection` based on movement vector
- Clears `PathBuffer` on arrival

### A2ASyncSystem

- Reads events from `A2AWebSocketClient` event queue
- Creates entities for new agents (with `SyncSource` + `ServerDriven`)
- Updates `AgentFsm.State` based on agent status messages
- Updates `CurrentTask` from task assignment/completion events
- Removes entities when agents disconnect

### TycoonTaskSystem

- Only runs when NOT in connected mode (no active WebSocket)
- Generates tasks at configurable intervals
- Assigns tasks to idle agents (nearest unassigned)
- Advances `CurrentTask.Progress` for working agents
- Emits task-complete events

### RenderBridgeSystem

- Iterates all agents, pushes data into `GameBridge` snapshot arrays
- Emits `GameBridge.AgentsUpdated` signal once per frame
- Minimal allocation — reuses pre-allocated Dictionary arrays

## GameWorld Class

```csharp
public sealed class GameWorld : IDisposable
{
    public IWorld World { get; }
    public ISystemRunner Runner { get; }
    public TileMap TileMap { get; }
    public PathCache PathCache { get; }
    public TaskRegistry TaskRegistry { get; }
    public List<string> AgentNames { get; }

    public GameWorld(int gridWidth, int gridHeight) { ... }
    public void Update(float deltaTime) => Runner.Update(deltaTime);
    public Entity SpawnAgent(string name, AgentRole role, int seatX, int seatY) { ... }
    public Entity SpawnFurniture(FurnitureType type, int x, int y, int rotation) { ... }
    public void Dispose() { ... }
}
```

Created by `AppHost._Ready()`, updated in `AppHost._Process()`.

## File Layout

```
project/hosts/complete-app/
+-- Ecs/
|   +-- Components.cs         -- All [EcsComponent] structs
|   +-- Enums.cs              -- AgentState, AgentRole, Direction, FurnitureType
|   +-- GameWorld.cs           -- World owner, entity spawning
|   +-- TileMap.cs             -- Grid data, walkability, BFS pathfinding
|   +-- PathCache.cs           -- Shared path storage
|   +-- TaskRegistry.cs        -- Task metadata lookup
|   +-- Systems/
|       +-- AgentFsmSystem.cs
|       +-- PathfindingSystem.cs
|       +-- MovementSystem.cs
|       +-- A2ASyncSystem.cs
|       +-- TycoonTaskSystem.cs
|       +-- RenderBridgeSystem.cs
+-- GameBridge.cs              -- C# autoload (see RFC-004)
+-- Net/
    +-- A2AWebSocketClient.cs  -- WebSocket client (see RFC-005)
```

## Open Questions

1. **Source generator compatibility with Godot.NET.Sdk** — UnifyEcs.Generators is a Roslyn analyzer. Need to verify it works with Godot's MSBuild pipeline. If not, fallback is writing systems manually against `IWorld` without source gen.

2. **Arch version** — UnifyEcs.Runtime.Arch depends on Arch 2.1.0. Need to confirm this resolves cleanly in Godot's net8.0 context.

3. **Component struct sizes** — Arch performs best with small components. `PathBuffer` delegates to `PathCache` to keep the struct small. Monitor if other components need similar treatment.

## Related RFCs

- [RFC-001](./RFC-001-game-architecture.md) — Overall architecture
- [RFC-003](./RFC-003-office-simulation.md) — TileMap and pathfinding details
- [RFC-004](./RFC-004-game-bridge.md) — How RenderBridgeSystem pushes data to GDScript
