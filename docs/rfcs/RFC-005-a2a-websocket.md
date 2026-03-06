# RFC-005: A2A WebSocket Transport

- **Status**: Draft
- **Created**: 2025-03-06

## Summary

Define how busy-office connects to a tentacle-punch A2A server over WebSocket, receives agent state updates in real-time, and maps them to ECS entities.

## Background

### A2A Protocol

[Agent-to-Agent (A2A)](https://google.github.io/A2A/) is Google's protocol for inter-agent communication. Key concepts:

- **AgentCard** — JSON metadata describing an agent's identity, skills, and capabilities. Discovered via `/.well-known/agent-card.json`.
- **Message** — JSON-RPC envelope containing a task or response. Method: `message/send`.
- **Task** — A unit of work with state: `submitted`, `working`, `input-required`, `completed`, `failed`, `canceled`.
- **Artifact** — Output produced by a task (text, file, etc.).

A2A is a **protocol**, not a transport. tentacle-punch currently serves it over HTTP, but WebSocket is equally valid and better suited for real-time visualization.

### tentacle-punch Architecture

tentacle-punch has:
- **Orchestrator** — LangGraph StateGraph that plans, spawns, and coordinates agents
- **Agent processes** — Individual HTTP servers (one per agent) with A2A endpoints
- **Workspace mode** — plan → spawn → execute → teardown → learn pipeline

The orchestrator exposes task state and agent status that busy-office needs.

## WebSocket Endpoint

### Server Side (tentacle-punch)

A new WebSocket endpoint is needed in tentacle-punch:

```
ws://<host>:<port>/a2a/stream
```

This endpoint streams A2A events as JSON-RPC notifications (server → client). The client can also send JSON-RPC requests (client → server) for queries.

### Message Types (Server → Client)

```jsonc
// Agent discovered or status changed
{
    "jsonrpc": "2.0",
    "method": "agent/status",
    "params": {
        "agent_id": "coder-1",
        "name": "Coder",
        "role": "coder",
        "status": "working",       // "idle", "working", "input-required", "offline"
        "activity": "typing",      // "typing", "reading", "idle", "meeting"
        "current_task": {
            "task_id": "task-42",
            "description": "Implement WebSocket client",
            "progress": 0.35
        }
    }
}

// Task lifecycle events
{
    "jsonrpc": "2.0",
    "method": "task/update",
    "params": {
        "task_id": "task-42",
        "state": "completed",      // A2A task states
        "agent_id": "coder-1",
        "description": "Implement WebSocket client",
        "artifacts": [...]         // Optional: task outputs
    }
}

// Agent connected/disconnected
{
    "jsonrpc": "2.0",
    "method": "agent/connected",
    "params": { "agent_id": "coder-1", "name": "Coder", "role": "coder" }
}
{
    "jsonrpc": "2.0",
    "method": "agent/disconnected",
    "params": { "agent_id": "coder-1" }
}

// Orchestrator state
{
    "jsonrpc": "2.0",
    "method": "orchestrator/state",
    "params": {
        "phase": "executing",      // "idle", "planning", "spawning", "executing", "teardown"
        "active_agents": 3,
        "pending_tasks": 5,
        "completed_tasks": 12
    }
}
```

### Message Types (Client → Server)

```jsonc
// Request current state snapshot (on connect)
{
    "jsonrpc": "2.0",
    "id": 1,
    "method": "state/snapshot",
    "params": {}
}

// Response
{
    "jsonrpc": "2.0",
    "id": 1,
    "result": {
        "agents": [...],           // Array of agent/status objects
        "tasks": [...],            // Array of active tasks
        "orchestrator": { "phase": "executing", ... }
    }
}
```

## Client Implementation (C#)

### A2AWebSocketClient

```csharp
public sealed class A2AWebSocketClient : IDisposable
{
    private ClientWebSocket? _ws;
    private CancellationTokenSource? _cts;
    private readonly ConcurrentQueue<A2AEvent> _eventQueue = new();

    public bool IsConnected { get; }
    public event Action? Connected;
    public event Action<string>? Disconnected;  // Reason

    public async Task ConnectAsync(string url) { ... }
    public async Task DisconnectAsync() { ... }
    public IEnumerable<A2AEvent> DrainEvents() { ... }  // Called by A2ASyncSystem
}
```

### Event Types

```csharp
public abstract record A2AEvent;

public record AgentStatusEvent(
    string AgentId,
    string Name,
    string Role,
    string Status,
    string Activity,
    string? TaskId,
    string? TaskDescription,
    float TaskProgress
) : A2AEvent;

public record AgentConnectedEvent(string AgentId, string Name, string Role) : A2AEvent;
public record AgentDisconnectedEvent(string AgentId) : A2AEvent;

public record TaskUpdateEvent(
    string TaskId,
    string State,
    string AgentId,
    string Description
) : A2AEvent;

public record OrchestratorStateEvent(
    string Phase,
    int ActiveAgents,
    int PendingTasks,
    int CompletedTasks
) : A2AEvent;
```

### Connection Lifecycle

```
1. User clicks "Connect" in hud-menubar
2.   GDScript calls GameBridge.Connect(url)
3.   GameBridge delegates to A2AWebSocketClient.ConnectAsync(url)
4.   WebSocket handshake completes
5.   Client sends state/snapshot request
6.   Server responds with current agents + tasks
7.   A2ASyncSystem creates ECS entities for each agent
8.   WebSocket receive loop starts (background task)
9.   Events queued in ConcurrentQueue
10.  Each frame, A2ASyncSystem drains queue and updates ECS
```

### Reconnection

On unexpected disconnect:
1. Emit `Disconnected` event with reason
2. Wait 2 seconds
3. Attempt reconnect (up to 3 retries with exponential backoff)
4. If all retries fail, fall back to tycoon mode
5. Remove `SyncSource` + `ServerDriven` tags from all entities

### Thread Safety

`ClientWebSocket` receive loop runs on a background thread. Events are pushed into a `ConcurrentQueue<A2AEvent>`. The ECS `A2ASyncSystem` runs on the main thread and drains the queue — no locking needed beyond the concurrent collection.

## A2ASyncSystem ↔ ECS Mapping

### Agent Discovery

When `AgentConnectedEvent` arrives:
1. Spawn new entity with: `AgentIdentity`, `AgentFsm`, `GridPosition`, `PixelPosition`, `SyncSource`, `ServerDriven`
2. Assign available seat (`SeatAssignment`)
3. Set initial position to seat
4. Map A2A role → `AgentRole` enum

### Status → FSM Mapping

| A2A Activity | AgentState |
|-------------|------------|
| `"idle"` | `Idle` |
| `"typing"` | `Typing` |
| `"reading"` | `Reading` |
| `"meeting"` | `Meeting` |

When status changes, `A2ASyncSystem` directly sets `AgentFsm.State` (bypassing normal FSM transitions since `ServerDriven` tag is present).

If the new state requires the agent to be at their desk (Typing/Reading) and they're not there, inject a Walking state first to animate the travel.

### Agent Disconnect

When `AgentDisconnectedEvent` arrives:
1. Find entity by `SyncSource.A2AAgentIndex`
2. Remove `SyncSource` and `ServerDriven` components
3. Entity falls back to tycoon FSM behavior (or despawn with animation)

## Configuration

```json
// data/connection.json (optional, for saved servers)
{
    "last_url": "ws://localhost:8080/a2a/stream",
    "auto_connect": false,
    "reconnect_attempts": 3,
    "reconnect_delay_ms": 2000
}
```

## Open Questions

1. **tentacle-punch WebSocket endpoint** — This endpoint (`/a2a/stream`) doesn't exist yet in tentacle-punch. Need to implement it there. The message schema above is a proposal — should align with tentacle-punch maintainers.

2. **Authentication** — No auth in the initial design. Add bearer token support later if needed.

3. **Bi-directional control** — Should busy-office be able to send commands to tentacle-punch (e.g., assign a task, pause an agent)? For Phase 4, read-only is sufficient. Control commands can be a Phase 5+ feature.

4. **Multiple orchestrators** — Current design assumes one tentacle-punch server. Supporting multiple would need entity namespacing.

## Related RFCs

- [RFC-001](./RFC-001-game-architecture.md) — Connected vs tycoon mode
- [RFC-002](./RFC-002-ecs-integration.md) — `A2ASyncSystem` and `SyncSource` component
- [RFC-004](./RFC-004-game-bridge.md) — Connection management through GameBridge
