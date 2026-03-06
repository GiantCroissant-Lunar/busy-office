---
name: bundle-arch
description: Background knowledge about busy-office bundle architecture, dock container zones, runtime flow, and bundle conventions. Activates when working with bundles, dock layout, registrars, or the HUD system.
user-invocable: false
---

# Bundle Architecture

## Runtime Flow

1. Godot starts -> `AppHost._Ready()` (autoload)
2. AppHost creates Bootstrap (ServiceArchi + PluginArchi DI)
3. AppHost creates BundleHost (VFS + SceneHost + DllExtractor)
4. BundleHost scans `bundles/` dir for `.pck` files
5. Each PCK: load VFS -> read `manifest.json` -> instantiate `entryScene`
6. Entry scene is a `registrar.gd` that finds DockContainer and calls `register_panel()`
7. Panel appears in a TabContainer zone

## Dock Zones

```
+----------+---------------+----------+
| LeftTop  |               | RightTop |
|   (0)    |  Center (1)   |   (2)    |
+----------+               +----------+
|LeftBottom|               |RightBottom|
|   (3)    |               |   (4)    |
+----------+---------------+----------+
|              Bottom (5)             |
+-------------------------------------+
```

## Key Paths

| File | Purpose |
|------|---------|
| `project/hosts/complete-app/AppHost.cs` | Autoload: Bootstrap + BundleHost init |
| `project/hosts/complete-app/Bootstrap.cs` | DI container |
| `project/hosts/complete-app/scripts/dock_container.gd` | 6-zone panel manager |
| `project/hosts/complete-app/scenes/hud_root.tscn` | Layout scene |
| `project/hosts/complete-app/scenes/main.tscn` | Root scene |
| `project/plugins/BusyOffice.Bundles.Core/BundleHost.cs` | PCK load/unload/reload |
| `project/plugins/BusyOffice.Bundles.Core/BundleVfs.cs` | PCK loading + manifest |
| `project/hosts/content-authoring/bundles/` | All GDScript bundles |

## Bundle Conventions

- Each bundle is a directory under `content-authoring/bundles/<name>/`
- Must have: `manifest.json`, `scripts/registrar.gd`, `scenes/registrar.tscn`
- Registrar finds DockContainer via tree traversal (HudRoot -> VBox/DockContainer)
- Uses `call_deferred` to handle load-order timing
- Panel scenes extend `PanelContainer`
- Resource paths use `res://bundles/<name>/...`

## Existing Bundles

| Bundle | Zone | Purpose |
|--------|------|---------|
| panel-welcome | 1 (Center) | Welcome screen with timestamp |
| hud-menubar | -1 (top slot) | File/Edit/View/Help menus |
| hud-statusbar | -1 (bottom slot) | FPS, bundle count, status |
| panel-scene-tree | 0 (LeftTop) | Document hierarchy tree |
| panel-inspector | 2 (RightTop) | Property editor |
| panel-timeline | 5 (Bottom) | Animation player/keyframes |
| panel-viewport | 1 (Center) | 2D canvas editor |
