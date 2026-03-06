# Busy Office — Handover Document

## What Was Built (Session 1)

Hot-reloadable bundle system with a 6-zone dock container HUD, adapted from fantasim-app-godot.

### Architecture

```
complete-app (Godot host)               content-authoring (GDScript bundles)
├── AppHost.cs (autoload)               └── bundles/
├── Bootstrap.cs (DI)                       └── panel-welcome/
├── scenes/main.tscn                            ├── manifest.json
│   └── instances hud_root.tscn                 ├── scripts/registrar.gd
├── scenes/hud_root.tscn                        ├── scripts/panel.gd
├── scripts/dock_container.gd                   ├── scenes/registrar.tscn
└── C# libraries:                               └── scenes/panel.tscn
    ├── BusyOffice.Bundles.Contracts
    └── BusyOffice.Bundles.Core
```

### Runtime Flow

1. Godot starts → `AppHost._Ready()` (autoload)
2. AppHost creates Bootstrap (ServiceArchi + PluginArchi DI)
3. AppHost creates BundleHost (VFS + SceneHost + DllExtractor)
4. BundleHost scans `bundles/` dir for `.pck` files
5. Each PCK: load VFS → read `manifest.json` → instantiate `entryScene`
6. Entry scene is a `registrar.gd` that finds DockContainer and calls `register_panel()`
7. Panel appears in a TabContainer zone

### Dock Zones

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
```

### Key Files

| File | Purpose |
|------|---------|
| `project/hosts/complete-app/AppHost.cs` | Node autoload — Bootstrap + BundleHost init, auto-loads PCKs |
| `project/hosts/complete-app/Bootstrap.cs` | DI container (ServiceArchi + PluginArchi + SharedAssemblyPolicy) |
| `project/hosts/complete-app/scripts/dock_container.gd` | 6-zone panel manager (register/unregister/move) |
| `project/hosts/complete-app/scenes/hud_root.tscn` | VSplitContainer + HSplitContainer + TabContainers layout |
| `project/hosts/complete-app/scenes/main.tscn` | Root scene, instances hud_root |
| `project/plugins/BusyOffice.Bundles.Core/BundleHost.cs` | Load/unload/reload PCK orchestrator |
| `project/plugins/BusyOffice.Bundles.Core/BundleVfs.cs` | PCK loading + manifest reading |
| `project/hosts/content-authoring/bundles/panel-welcome/` | Sample bundle (registrar + panel with timestamp) |
| `design/dock-container.json` | boom-hud DSL describing the dock layout |

### Build Commands

```bash
# Build & export app
task build:app

# Build panel-welcome bundle PCK
task build:bundle:panel-welcome

# Run exported app
task run:complete-app

# Open in Godot editor
task run:complete-app:editor
```

### Current State

- C# builds clean (0 errors, 0 warnings)
- Exported app runs, Bootstrap + BundleHost initialize successfully
- panel-welcome PCK not yet built (bundle loads at runtime, not at build time yet)
- pre-commit hooks active: trailing-whitespace, end-of-file-fixer, check-yaml/json, ruff lint+format

---

## Next Session Plan: Editor-Style HUD

Transform the dock container into a full editor-like interface with these bundles:

### 1. Menu Bar (bundle: `hud-menubar`)

- Top of window, outside dock container (zone -1 or dedicated slot)
- File, Edit, View, Help menus
- GDScript `MenuBar` / `PopupMenu` nodes
- Emits signals for actions (new, open, save, undo, redo, etc.)

### 2. Status Bar (bundle: `hud-statusbar`)

- Bottom of window, outside dock container (dedicated slot below zone 5)
- Shows: current time, FPS, bundle count, selected item info
- Thin horizontal bar with labels

### 3. Timeline / Animation Player (bundle: `panel-timeline`)

- Docks in **Bottom zone (5)**
- AnimationPlayer-like UI: playhead, keyframes, tracks
- Transport controls (play/pause/stop/step)
- Time ruler with zoom
- Track list on left, keyframe area on right
- This is the core "animation tree" editor

### 4. Inspector (bundle: `panel-inspector`)

- Docks in **Right zone (2)**
- Shows properties of selected item
- Dynamic property list (labels + editors)
- Reacts to selection changes
- Supports different property types (string, number, bool, color, enum)

### 5. Scene Tree / Hierarchy (bundle: `panel-scene-tree`)

- Docks in **Left zone (0)**
- Tree widget showing document hierarchy
- Drag-and-drop reordering
- Selection syncs with Inspector and Timeline
- Context menu (add, delete, rename, duplicate)

### 6. Viewport / Canvas (bundle: `panel-viewport`)

- Docks in **Center zone (1)** (replaces panel-welcome)
- 2D canvas for visual editing
- Shows the scene being edited
- Selection handles, gizmos

### Implementation Order

```
1. hud-menubar + hud-statusbar  (structural — modify main.tscn to add slots)
2. panel-scene-tree              (data model + selection state)
3. panel-inspector               (reacts to selection)
4. panel-timeline                (animation system — most complex)
5. panel-viewport                (visual canvas — depends on data model)
```

### Architectural Decisions Needed

- **Selection State**: Need a shared selection singleton (C# or GDScript autoload?) that all panels observe. fantasim-app-godot uses a `SelectionState` autoload — follow same pattern.
- **Document Model**: What data structure represents the "document" being edited? Need to define this before building Scene Tree + Inspector.
- **Menu Bar / Status Bar placement**: Either add dedicated VBox slots in main.tscn (above/below DockContainer) or make them bundles that register into non-dock zones.
- **Timeline data model**: What are "tracks" and "keyframes"? Need to decide if this is a generic animation system or domain-specific.

### Reference Files (fantasim-app-godot)

| What | Path |
|------|------|
| Inspector panel | `content-authoring/bundles/panel-inspector/scripts/panel.gd` |
| Scene tree panel | `content-authoring/bundles/panel-scene-tree/scripts/panel.gd` |
| Viewport panel | `content-authoring/bundles/panel-viewport/scripts/panel.gd` |
| Registrar pattern | `content-authoring/bundles/panel-viewport/scripts/registrar.gd` |
| Dock container | `content-authoring/bundles/hud-control/scripts/dock_container.gd` |
| AppHost (autoload) | `complete-app/AppHost.cs` |
