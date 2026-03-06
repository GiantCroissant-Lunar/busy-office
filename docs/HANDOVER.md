# Busy Office — Handover Document

## What Was Built

### Session 1 — Bundle System + Editor HUD

Hot-reloadable bundle system with a 6-zone dock container HUD, adapted from fantasim-app-godot.

- C# host: AppHost (autoload) → Bootstrap (ServiceArchi + PluginArchi DI) → BundleHost
- 7 GDScript bundles: panel-welcome, hud-menubar, hud-statusbar, panel-scene-tree, panel-inspector, panel-timeline, panel-viewport
- GDScript autoloads: SelectionState, EditorDocument (mock scene tree)
- Pre-commit hooks: trailing-whitespace, end-of-file-fixer, check-yaml/json, ruff

### Session 2 — Project Pivot + RFCs + CI

Pivoted from editor UI to **agent swarm visualizer + office tycoon game**.

**Research completed:**
- **unify-ecs** — source-gen ECS meta-framework, Arch backend most mature (net8.0 compatible)
- **tentacle-punch** — Python A2A agent swarm over HTTP JSON-RPC, LangGraph orchestrator
- **pixel-agents** — VS Code extension, visual reference for pixel-art office (16x24 sprites, tile grid, FSM)

**RFCs written** (`docs/rfcs/`):

| RFC | Title | Key Decisions |
|-----|-------|---------------|
| 001 | Game Architecture | Two modes (connected + tycoon), ECS + Godot, editor HUD retained |
| 002 | ECS Integration | unify-ecs + Arch, component structs, 6 systems, file layout |
| 003 | Office Simulation | 24x16 tile grid, 16px tiles, BFS pathfinding, agent FSM (Idle/Walking/Sitting/Typing/Reading) |
| 004 | C#-GDScript Bridge | GameBridge autoload, Dictionary arrays + signals, snapshot pattern |
| 005 | A2A WebSocket | JSON-RPC over WebSocket, event types, reconnection, thread safety |
| 006 | Tycoon Mode | Task types, generation, economy (credits), progression curve |

**CI/CD set up:**
- `gh aw init` — GitHub Agentic Workflows
- `pr-review-resolver` — `/resolve-reviews` command on PRs (Copilot engine)
- `auto-merge-copilot` — auto-squash Copilot sub-PRs
- `COPILOT_GITHUB_TOKEN` secret configured

---

## Current State

- All 7 bundles built and functional (editor-style, will be rewritten for game)
- C# builds clean, exported app runs
- RFCs approved for implementation
- GitHub remote: `GiantCroissant-Lunar/busy-office`
- No ECS packages in local NuGet feed yet

---

## Next Session: Phase 0 — Build UnifyEcs Packages

### Goal

Get unify-ecs NuGet packages into the local feed so `complete-app.csproj` can reference them.

### Steps

```bash
cd C:\lunar-horse\plate-projects\unify-ecs

# 1. Restore tools
dotnet tool restore

# 2. Get version
export GITVERSION_MAJORMINORPATCH=$(bash tools/gitversion.sh | python -c "import sys,json;print(json.load(sys.stdin)['MajorMinorPatch'])")

# 3. Build + pack
dotnet tool run unify-build -- PackProjects

# 4. Sync to local feed
cp build/_artifacts/*/nuget/*.nupkg C:\lunar-horse\packages\nuget\flat/
```

### Verify

```bash
ls C:\lunar-horse\packages\nuget\flat/UnifyEcs*
# Should see: UnifyEcs.Core, UnifyEcs.Attributes, UnifyEcs.Generators, UnifyEcs.Runtime.Arch
```

### Then Phase 1

After packages are in the feed, proceed with Phase 1 (RFC-002):

1. Add `UnifyEcs.*` NuGet refs to `complete-app.csproj`
2. Create `Ecs/Components.cs` — component structs
3. Create `Ecs/GameWorld.cs` — world owner
4. Create `GameBridge.cs` — C# autoload (RFC-004)
5. Wire into `AppHost._Process()`
6. Rewrite panel-viewport → tile grid renderer
7. Rewrite panel-scene-tree → agent list
8. Rewrite panel-inspector → agent properties
9. Update hud-statusbar → game stats

---

## Architecture Reference

```
complete-app (Godot host)               content-authoring (GDScript bundles)
├── AppHost.cs (autoload)               └── bundles/
├── Bootstrap.cs (DI)                       ├── panel-welcome/
├── GameBridge.cs (autoload, NEW)           ├── hud-menubar/
├── Ecs/ (NEW)                              ├── hud-statusbar/
│   ├── Components.cs                       ├── panel-scene-tree/
│   ├── GameWorld.cs                        ├── panel-inspector/
│   ├── TileMap.cs                          ├── panel-timeline/
│   └── Systems/                            └── panel-viewport/
├── Net/ (NEW)
│   └── A2AWebSocketClient.cs
├── scenes/main.tscn
│   └── instances hud_root.tscn
├── scripts/dock_container.gd
└── C# libraries:
    ├── BusyOffice.Bundles.Contracts
    └── BusyOffice.Bundles.Core
```

### Dock Zones (unchanged)

```
┌──────────┬───────────────┬──────────┐
│ LeftTop  │               │ RightTop │
│  (0)     │   Center (1)  │   (2)    │
├──────────┤               ├──────────┤
│LeftBottom│               │RightBottom│
│  (3)     │               │   (4)    │
├──────────┴───────────────┴──────────┤
│            Bottom (5)               │
└─────────────────────────────────────┘

Zone 0: panel-scene-tree (agent list)
Zone 1: panel-viewport (office tile grid)
Zone 2: panel-inspector (agent properties)
Zone 5: panel-timeline (activity log)
```

### Key Dependencies

| Dependency | Location | Status |
|------------|----------|--------|
| unify-ecs (Arch) | `C:\lunar-horse\plate-projects\unify-ecs` | Needs build + feed sync |
| tentacle-punch | `github.com/GiantCroissant-Lunar/tentacle-punch` | Phase 4 (WebSocket endpoint needed) |
| pixel-agents | `github.com/pablodelucca/pixel-agents` | Visual reference only |

### Build Commands

```bash
task build:app                # Export complete-app.exe
task build:bundles --force    # Export all bundle PCKs
task run:complete-app         # Run exported app
task run:complete-app:editor  # Open in Godot editor
```
