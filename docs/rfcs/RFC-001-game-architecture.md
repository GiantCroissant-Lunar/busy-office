# RFC-001: Game Architecture Overview

- **Status**: Draft
- **Created**: 2025-03-06

## Summary

Transform busy-office from an editor-style UI framework into an agent swarm visualizer with an offline tycoon mode. The app shows a pixel-art office where AI agents (from tentacle-punch) or simulated agents work on tasks. When connected to a tentacle-punch server, real agent activity drives the visualization. When disconnected, a local tycoon simulation takes over.

## Motivation

### Problem

tentacle-punch orchestrates AI agent swarms (coder, reviewer, test-writer, etc.) but has no visual representation of what agents are doing. Understanding swarm behavior requires reading logs and JSON-RPC traces. A visual client makes agent coordination tangible and entertaining.

### Goals

1. **Visualize agent swarms** — each AI agent maps to a pixel character in a 2D office
2. **Client-server architecture** — connect to tentacle-punch via WebSocket (A2A protocol)
3. **Standalone tycoon mode** — fun simulation when no server is available
4. **Leverage existing infrastructure** — keep the editor HUD, bundle system, and DI stack
5. **ECS-driven simulation** — use unify-ecs (Arch backend) for performant entity management

### Non-Goals

- Replacing tentacle-punch's orchestration logic
- Building a full game engine (Godot handles rendering)
- Supporting multiple concurrent server connections
- Mobile or web export (Windows desktop only for now)

## Design Overview

```
busy-office (Godot 4.6.1 + C#)
+-------------------------------------------------------+
|  AppHost (autoload)                                    |
|  +-- Bootstrap (ServiceArchi DI)                       |
|  +-- BundleHost (PCK loader)                           |
|  +-- GameWorld (unify-ecs + Arch)                      |
|  +-- GameBridge (autoload, C#->GDScript interop)       |
|  +-- A2AWebSocketClient (optional connection)          |
+-------------------------------------------------------+
|  GDScript Bundles (loaded as PCKs)                     |
|  +-- panel-viewport  -> office tile grid renderer      |
|  +-- panel-scene-tree -> agent list                    |
|  +-- panel-inspector  -> selected agent/object props   |
|  +-- panel-timeline   -> activity log / task queue     |
|  +-- hud-menubar      -> game menus + connect          |
|  +-- hud-statusbar    -> connection + tycoon stats     |
+-------------------------------------------------------+
         |  WebSocket (optional)
         v
+------------------------+
| tentacle-punch         |
| A2A agent swarm server |
+------------------------+
```

## Two Modes

### Connected Mode

1. User enters tentacle-punch WebSocket URL via menu
2. `A2AWebSocketClient` connects and discovers agent cards
3. Each real agent becomes an ECS entity with `SyncSource` component
4. Agent activities (coding, reviewing, idle) update `AgentFsm` state
5. Task assignments and completions flow in real-time
6. Local FSM logic is overridden — agents move based on server state

### Tycoon Mode (Offline)

1. No server connection — simulation runs locally
2. `TycoonTaskSystem` generates tasks at intervals
3. Agents pick tasks, walk to desks, work, complete, repeat
4. Player can: add agents, assign desks, adjust speed
5. Stats tracked: tasks completed, agents active, idle time

### Mode Switching

Both modes coexist. Entities with `SyncSource` are server-driven; entities without are locally simulated. Disconnecting from the server removes `SyncSource` components, and agents fall back to tycoon behavior.

## Tech Stack Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| ECS framework | unify-ecs + Arch backend | In-house, source-gen, net8.0 compatible |
| Rendering | Godot 4.6.1 + GDScript bundles | Existing infrastructure, hot-reload PCKs |
| C#-GDScript bridge | `GameBridge` autoload | Standard Godot interop via Dictionary + signals |
| Networking | `System.Net.WebSockets.ClientWebSocket` | Built into net8.0, no extra deps |
| A2A protocol | JSON-RPC over WebSocket | A2A is protocol not transport; WS gives real-time |
| Tile size | 16x16 pixels | Matches pixel-agents aesthetic, standard for pixel art |

## Existing Infrastructure Retained

- **Editor HUD** — 6-zone dock container with TabContainers stays as-is
- **Bundle system** — PCK hot-reload, registrar pattern, DockContainer registration
- **DI stack** — ServiceArchi + PluginArchi + SharedAssemblyPolicy
- **Build system** — unify-build, Taskfile, GitVersion, pre-commit hooks

## Existing Infrastructure Replaced

| Old | New | Why |
|-----|-----|-----|
| `EditorDocument` autoload | `GameBridge` autoload | Different data model (agents vs scene tree) |
| `SelectionState` autoload | `GameBridge.SelectAgent()` | Unified bridge, fewer autoloads |
| Mock scene tree data | ECS world | Real simulation state |

## Implementation Phases

| Phase | Scope | Runnable? |
|-------|-------|-----------|
| 0 | Build unify-ecs, sync to local feed | N/A |
| 1 | ECS core + GameBridge + static agents on grid | Yes |
| 2 | Agent FSM + movement + pathfinding | Yes |
| 3 | Tycoon mode (task generation + economy) | Yes |
| 4 | WebSocket A2A connected mode | Yes |
| 5 | Polish (sprites, sound, save/load) | Yes |

Each phase produces a runnable app. Details in subsequent RFCs.

## Related RFCs

- [RFC-002](./RFC-002-ecs-integration.md) — ECS components and systems
- [RFC-003](./RFC-003-office-simulation.md) — Tile grid, pathfinding, FSM
- [RFC-004](./RFC-004-game-bridge.md) — C#-GDScript bridge
- [RFC-005](./RFC-005-a2a-websocket.md) — WebSocket A2A transport
- [RFC-006](./RFC-006-tycoon-mode.md) — Tycoon mode design
