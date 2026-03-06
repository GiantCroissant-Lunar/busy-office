# RFC-006: Tycoon Mode

- **Status**: Draft
- **Created**: 2025-03-06

## Summary

Define the offline tycoon simulation: task generation, agent work cycles, economy, progression, and player interaction. Tycoon mode is the default when no tentacle-punch server is connected.

## Design Principles

1. **Start simple** — Phase 3 implements core task loop only. Economy and upgrades come later.
2. **ECS-native** — All tycoon logic lives in ECS systems, not in GDScript
3. **Seamless transition** — Tycoon agents and server agents coexist. Disconnecting from a server doesn't reset progress.

## Task System

### Task Types

```csharp
public enum TaskType
{
    WriteCode,      // Agent types at desk
    ReviewCode,     // Agent reads at desk
    FixBug,         // Agent types at desk
    WriteTests,     // Agent types at desk
    WriteDocs,      // Agent reads, then types
    Research,       // Agent reads at desk
    Meeting,        // Agent goes to whiteboard (future)
    Deploy,         // Agent types at desk (future)
}
```

### Task Definition

```csharp
public struct TaskDef
{
    public string Description;
    public TaskType Type;
    public float BaseDuration;    // Seconds at 1x speed
    public int Reward;            // Currency earned on completion
    public AgentRole? PreferredRole; // null = any agent
}
```

### Task Registry

Pre-defined task templates stored in `TaskRegistry`:

| Description | Type | Duration | Reward | Preferred Role |
|-------------|------|----------|--------|----------------|
| "Implement login endpoint" | WriteCode | 30s | 100 | Coder |
| "Review auth module PR" | ReviewCode | 20s | 60 | Reviewer |
| "Fix null pointer in parser" | FixBug | 25s | 80 | Coder |
| "Write unit tests for API" | WriteTests | 25s | 70 | TestWriter |
| "Document REST API" | WriteDocs | 20s | 50 | DocsWriter |
| "Research caching strategies" | Research | 15s | 40 | Any |
| "Sprint planning" | Meeting | 40s | 30 | Any |

Durations are intentionally short (15-40s at 1x) for visual feedback. Real-time feel at 1x, fast-forward at 4x.

### Task Generation

`TycoonTaskSystem` generates tasks at configurable intervals:

```
Base interval: 5 seconds (at 1x speed)
Variance: +/- 2 seconds (random)
Queue cap: 10 pending tasks (stops generating when full)
```

Task type is weighted random. Task description is picked from the template pool with slight variation (append ticket numbers, module names).

### Task Assignment

When a task is generated:
1. Check for idle agents matching `PreferredRole` (if specified)
2. If no preferred match, pick any idle agent
3. If no idle agents, task stays in queue
4. Assigned agent gets `CurrentTask` component, FSM transitions to Walking (toward desk)

Assignment priority: longest-idle agent first (prevents one agent getting all tasks).

## Agent Work Cycle

```
Task Generated
    |
    v
[Queue] --assign--> Agent receives CurrentTask
    |
    v
Agent walks to desk (Walking state)
    |
    v
Agent sits down (Sitting state, 0.3s)
    |
    v
Agent works (Typing or Reading based on TaskType)
    |  Progress increments: delta / Duration
    v
Progress reaches 1.0
    |
    v
Task complete: remove CurrentTask, emit event, add reward
    |
    v
Agent returns to Idle
```

### Task Type → Work State

| TaskType | AgentState | Visual |
|----------|------------|--------|
| WriteCode | Typing | Typing animation |
| ReviewCode | Reading | Reading animation |
| FixBug | Typing | Typing animation |
| WriteTests | Typing | Typing animation |
| WriteDocs | Reading → Typing | 40% reading, 60% typing |
| Research | Reading | Reading animation |
| Meeting | Meeting | At whiteboard (future) |

## Economy (Phase 3+)

### Currency

Single currency: **Credits**. Earned by completing tasks.

### Initial Balance

Start with 500 credits. Enough to hire 2 additional agents.

### Costs

| Action | Cost |
|--------|------|
| Hire agent (Coder) | 200 |
| Hire agent (Reviewer) | 150 |
| Hire agent (TestWriter) | 150 |
| Hire agent (DocsWriter) | 100 |
| Buy desk + chair | 50 |
| Buy plant (morale) | 30 |
| Buy cooler (morale) | 40 |
| Buy whiteboard (meetings) | 80 |

### Income

Task rewards (see task table above). Roughly 100-200 credits per minute at 1x with 4 agents.

### Balance Display

Shown in `hud-statusbar`: "Credits: 1,250"

## Player Actions

### Phase 3 (Minimal)

Available through `hud-menubar`:
- **Hire Agent** — submenu with role selection. Spawns at next free seat.
- **Speed** — 1x / 2x / 4x simulation speed
- **Pause** — Stop simulation (0x)

### Future Phases

- **Place Furniture** — Buy and place desks, plants, etc. on the tile grid
- **Expand Office** — Increase grid size (buy more floor tiles)
- **Upgrade Desks** — Faster task completion for agents at upgraded desks
- **Agent Skills** — Agents gain XP, level up, work faster
- **Contracts** — Accept multi-task contracts for bonus rewards
- **Reputation** — Completing contracts builds reputation, unlocks better contracts

## ECS Components for Tycoon

```csharp
[EcsComponent]
public struct TycoonWallet
{
    public int Credits;
}

[EcsComponent]
public struct AgentCost
{
    public int HireCost;
    public float Efficiency;   // Multiplier on work speed (1.0 default)
}
```

`TycoonWallet` is a singleton entity (one per world). `AgentCost` is per-agent.

## TycoonTaskSystem

```csharp
[EcsSystem(Phase = SystemPhase.EarlyUpdate, Order = 10)]
public partial class TycoonTaskSystem
{
    [Inject] public IWorld World { get; set; }
    [Inject] public ICommandBuffer Commands { get; set; }

    // System manages:
    // - Task generation timer
    // - Task queue (List<TaskDef>)
    // - Task assignment to idle agents
    // - Progress advancement for working agents
    // - Task completion + reward
}
```

The system only runs when `GameWorld.IsConnected == false` (no active WebSocket). When a server connects, task generation stops but existing tasks complete.

## Tycoon Stats

Exposed via `GameBridge.GetTycoonStats()`:

```gdscript
{
    "credits": 1250,
    "tasks_completed": 47,
    "tasks_pending": 3,
    "tasks_active": 4,
    "agent_count": 6,
    "idle_agents": 2,
    "sim_speed": 2.0,
    "is_connected": false,
    "total_earnings": 4200,
}
```

## Panel Adaptations

### panel-timeline → Activity Log

Rewritten to show:
- Scrolling log of events: "Alice completed 'Implement login endpoint' (+100 credits)"
- Pending task queue with descriptions
- Active tasks with progress bars

### panel-inspector → Agent Details

When an agent is selected:
- Name, role, palette
- Current state (Idle/Working/Walking)
- Current task description + progress
- Tasks completed count
- Efficiency rating
- (Future: XP, level, skills)

### hud-statusbar → Tycoon Bar

- Credits display
- Agent count (idle/total)
- Tasks completed counter
- Connection status
- Sim speed indicator

### hud-menubar → Game Menu

- **Game** → Hire Agent (submenu), Pause, Speed (submenu)
- **Connect** → Enter URL, Disconnect
- **View** → Toggle panels
- **Help** → About

## Persistence (Future)

Save tycoon state to JSON:

```json
{
    "credits": 1250,
    "agents": [
        { "name": "Alice", "role": "coder", "seat": [3, 2], "tasks_completed": 15 }
    ],
    "furniture": [...],
    "stats": { "total_tasks": 47, "total_earnings": 4200 }
}
```

Saved to `user://save.json` (Godot user data dir). Not implemented in Phase 3.

## Progression Curve

| Time (1x) | Agents | Credits/min | Unlocks |
|------------|--------|-------------|---------|
| 0 min | 4 (free) | ~120 | Starting office |
| 5 min | 5 | ~150 | First hire |
| 10 min | 6 | ~180 | Second hire |
| 20 min | 8 | ~240 | Full office |
| 30 min | 8+ | ~300 | Furniture upgrades |

At 4x speed, this compresses to ~8 minutes to fill the office.

## Open Questions

1. **Agent names** — Random from a pool? Or user-named? Pool is simpler for Phase 3.

2. **Task failure** — Can tasks fail? Or always complete? Failure adds depth but complexity. Skip for Phase 3.

3. **Agent idle cost** — Should idle agents cost upkeep (salary)? Creates pressure to keep agents busy. Good for depth, skip for Phase 3.

4. **Multi-task agents** — Can an agent work on multiple tasks sequentially without returning to idle? Probably not — the walk-sit-work cycle is the visual payoff.

## Related RFCs

- [RFC-002](./RFC-002-ecs-integration.md) — ECS systems and components
- [RFC-003](./RFC-003-office-simulation.md) — Agent FSM that tycoon drives
- [RFC-004](./RFC-004-game-bridge.md) — Stats and events exposed to GDScript
