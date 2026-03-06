# RFC-004: C#-GDScript Bridge

- **Status**: Draft
- **Created**: 2025-03-06

## Summary

Define the `GameBridge` C# autoload that exposes ECS simulation state to GDScript bundles. This is the sole communication channel between the C# ECS world and the GDScript rendering/UI layer.

## Problem

GDScript cannot:
- Access C# generics (no `world.Get<Position>(entity)`)
- Import C# struct types
- Iterate ECS queries directly

The bridge must marshal ECS data into Godot-native types that GDScript understands: `Dictionary`, `Array`, `String`, `int`, `float`, `Vector2`, `Vector2i`.

## Design

### GameBridge Node

```csharp
public partial class GameBridge : Node
{
    // Singleton access from C#
    public static GameBridge Instance { get; private set; }

    // --- Signals (GDScript connects to these) ---
    [Signal] public delegate void AgentsUpdatedEventHandler();
    [Signal] public delegate void AgentSelectedEventHandler(string agentId);
    [Signal] public delegate void TaskCompletedEventHandler(string agentName, string taskDesc);
    [Signal] public delegate void ConnectionStatusChangedEventHandler(bool connected);

    // --- Agent Queries ---
    public Godot.Collections.Array<Godot.Collections.Dictionary> GetAgents();
    public Godot.Collections.Dictionary GetAgent(int entityId);
    public int GetAgentCount();

    // --- Furniture Queries ---
    public Godot.Collections.Array<Godot.Collections.Dictionary> GetFurniture();

    // --- Selection ---
    public void SelectAgent(int entityId);
    public void ClearSelection();
    public int GetSelectedAgentId();  // -1 if none

    // --- Grid Info ---
    public int GetGridWidth();
    public int GetGridHeight();
    public int GetTileSize();  // Always 16
    public Godot.Collections.Array<int> GetWalkableTiles();  // Flat bool array as int (0/1)

    // --- Tycoon Stats ---
    public Godot.Collections.Dictionary GetTycoonStats();

    // --- Connection ---
    public void Connect(string url);
    public void Disconnect();
    public bool IsConnected();

    // --- Speed Control ---
    public void SetSimSpeed(float multiplier);  // 1.0, 2.0, 4.0
    public float GetSimSpeed();
}
```

### Agent Dictionary Schema

Each agent is a `Dictionary` with these keys:

```gdscript
{
    "id": int,              # Stable entity ID
    "name": String,         # Agent name
    "role": String,         # "coder", "reviewer", "test_writer", "docs_writer", "learner"
    "palette": int,         # Palette index (0-5)
    "grid_x": int,          # Tile X
    "grid_y": int,          # Tile Y
    "pixel_x": float,       # Interpolated pixel X
    "pixel_y": float,       # Interpolated pixel Y
    "facing": int,          # 0=down, 1=left, 2=right, 3=up
    "state": String,        # "idle", "walking", "sitting", "typing", "reading", "meeting"
    "task_desc": String,    # Current task description (empty if none)
    "task_progress": float, # 0.0 to 1.0 (-1.0 if no task)
    "is_server": bool,      # true if driven by tentacle-punch
}
```

### Furniture Dictionary Schema

```gdscript
{
    "id": int,              # Entity ID
    "type": String,         # "desk", "chair", "bookshelf", "plant", "cooler", "whiteboard", "pc", "lamp"
    "grid_x": int,
    "grid_y": int,
    "rotation": int,        # 0, 90, 180, 270
}
```

### Tycoon Stats Dictionary Schema

```gdscript
{
    "tasks_completed": int,
    "tasks_pending": int,
    "tasks_active": int,
    "agent_count": int,
    "idle_agents": int,
    "sim_speed": float,
    "is_connected": bool,
}
```

## Data Flow

### Per-Frame Update

```
1. AppHost._Process(delta)
2.   GameWorld.Update(delta * simSpeed)
3.     ECS systems run (FSM, pathfinding, movement, etc.)
4.     RenderBridgeSystem executes last:
5.       Iterates all agents → builds Dictionary arrays
6.       Iterates all furniture → builds Dictionary arrays
7.       Stores in GameBridge snapshot fields
8.       Emits AgentsUpdated signal
9. GDScript bundles receive signal:
10.   panel-viewport: queue_redraw()
11.   panel-scene-tree: rebuild_list()
12.   panel-inspector: update_properties()
```

### Snapshot Pattern

`RenderBridgeSystem` writes into pre-allocated arrays in `GameBridge`. GDScript reads these arrays when handling the signal. This avoids allocating new arrays every frame.

```csharp
// GameBridge internal state
private Godot.Collections.Array<Godot.Collections.Dictionary> _agentSnapshot = new();
private Godot.Collections.Array<Godot.Collections.Dictionary> _furnitureSnapshot = new();
private bool _furnitureDirty = true;  // Only rebuild when furniture changes

public Godot.Collections.Array<Godot.Collections.Dictionary> GetAgents() => _agentSnapshot;
public Godot.Collections.Array<Godot.Collections.Dictionary> GetFurniture() => _furnitureSnapshot;
```

Agent snapshots are rebuilt every frame (agents move). Furniture snapshots are rebuilt only when furniture changes (rare).

### Selection Flow

```
1. GDScript panel-viewport: user clicks agent sprite
2.   Calls GameBridge.SelectAgent(entityId)
3. GameBridge stores _selectedAgentId, emits AgentSelected
4. GDScript panel-inspector: receives signal, calls GetAgent(id)
5. GDScript panel-scene-tree: receives signal, highlights tree item
6. GDScript panel-viewport: receives signal, draws selection highlight
```

## Autoload Registration

In `project.godot`:

```ini
[autoload]
AppHost="*res://AppHost.cs"
GameBridge="*res://GameBridge.cs"
```

`GameBridge` must load after `AppHost` (Godot loads autoloads in order). `AppHost._Ready()` sets `GameBridge.Instance` and wires the ECS world.

Alternatively, `AppHost` creates `GameBridge` programmatically and adds it to the scene tree, avoiding a separate autoload entry.

## Bundle Consumption Pattern

Each GDScript bundle finds `GameBridge` at runtime:

```gdscript
# In any bundle's panel.gd
var bridge: Node

func _ready():
    bridge = get_node("/root/GameBridge")
    bridge.connect("agents_updated", _on_agents_updated)
    bridge.connect("agent_selected", _on_agent_selected)

func _on_agents_updated():
    var agents = bridge.GetAgents()
    # Render or display agent data...

func _on_agent_selected(agent_id: String):
    var agent = bridge.GetAgent(int(agent_id))
    # Update inspector or highlight...
```

Note: GDScript calls PascalCase C# methods directly. Signal names are snake_case (Godot convention for signal emission).

## Performance Considerations

### Dictionary Allocation

Each agent Dictionary is ~13 key-value pairs. For 16 agents, that's 16 Dictionaries per frame. Godot's Dictionary is heap-allocated but lightweight. For up to ~100 agents this is negligible.

If agent count grows beyond 100, consider:
- Flat parallel arrays instead of Dictionary per agent
- Only sending changed agents (delta updates)

For Phase 1-3, the Dictionary approach is simple and sufficient.

### Signal Frequency

`AgentsUpdated` fires once per frame (60Hz). GDScript panels should avoid expensive operations in the handler — just `queue_redraw()` and let `_draw()` read the snapshot.

## What GameBridge Does NOT Do

- **Does not own the ECS world** — `GameWorld` owns it, `GameBridge` reads from it
- **Does not run systems** — `AppHost._Process()` drives the update loop
- **Does not manage bundles** — `BundleHost` handles PCK loading
- **Does not handle networking** — `A2AWebSocketClient` is separate (see RFC-005)

GameBridge is a read-mostly facade with two write paths: `SelectAgent()` and `Connect()`/`Disconnect()`.

## Related RFCs

- [RFC-002](./RFC-002-ecs-integration.md) — Components and systems that produce bridge data
- [RFC-003](./RFC-003-office-simulation.md) — Simulation state being bridged
- [RFC-005](./RFC-005-a2a-websocket.md) — Connection management exposed through bridge
