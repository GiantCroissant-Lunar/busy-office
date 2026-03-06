---
name: new-bundle
description: Scaffold a new GDScript bundle for busy-office (panel or HUD element). Creates manifest, registrar, panel scene, and Taskfile entry.
disable-model-invocation: true
argument-hint: "<bundle-name> [zone:0-5]"
---

# New Bundle

Scaffold a new GDScript bundle under `project/hosts/content-authoring/bundles/`.

## Arguments

- `$0` — bundle name (e.g. `panel-properties`, `hud-toolbar`). Required.
- `$1` — dock zone (0-5). Default: 1 (Center).

## Dock Zones

```
0 = LeftTop     1 = Center      2 = RightTop
3 = LeftBottom                  4 = RightBottom
               5 = Bottom
```

## Steps

1. Create directory: `project/hosts/content-authoring/bundles/$0/`
2. Create subdirectories: `scripts/`, `scenes/`
3. Create `manifest.json`:

```json
{
  "bundleId": "$0",
  "version": "0.1.0",
  "displayName": "<title-cased name>",
  "entryScene": "scenes/registrar.tscn",
  "scenes": [
    "scenes/registrar.tscn",
    "scenes/panel.tscn"
  ],
  "metadata": {}
}
```

4. Create `scripts/registrar.gd` following the registrar pattern:

```gdscript
extends Node

const PANEL_ID := "$0"
const PANEL_TITLE := "<title-cased name>"
const PANEL_ZONE := $1
const PANEL_SCENE := "res://bundles/$0/scenes/panel.tscn"

func _ready() -> void:
	_register.call_deferred()

func _register() -> void:
	var dock := _find_dock_container()
	if dock:
		_do_register(dock)
	else:
		get_tree().root.child_entered_tree.connect(_on_root_child)

func _on_root_child(node: Node) -> void:
	if node.name == "HudRoot" or node.name == "Main":
		get_tree().root.child_entered_tree.disconnect(_on_root_child)
		var dock := _find_dock_container()
		if dock:
			_do_register.call_deferred(dock)

func _do_register(dock: Node) -> void:
	var scene := load(PANEL_SCENE) as PackedScene
	if scene:
		dock.register_panel(PANEL_ID, PANEL_TITLE, scene.instantiate(), PANEL_ZONE)

func _find_dock_container() -> Node:
	for child in get_tree().root.get_children():
		if child.name == "HudRoot":
			return child.get_node_or_null("VBox/DockContainer")
		var hud := child.get_node_or_null("HudRoot")
		if hud:
			return hud.get_node_or_null("VBox/DockContainer")
	return null
```

5. Create `scripts/panel.gd` — basic PanelContainer with a centered label.

6. Create `scenes/registrar.tscn` — Node root with `scripts/registrar.gd` attached.

7. Create `scenes/panel.tscn` — PanelContainer root with `scripts/panel.gd` attached.

8. Add a Taskfile entry in `Taskfile.yml` under bundle build tasks:

```yaml
"build:bundle:$0":
  desc: Build $0 bundle PCK
  deps: ["ensure:dirs"]
  cmds:
    - mkdir -p "{{.APP_DIR}}/bundles"
    - '"{{.GODOT}}" --headless --path "{{.CONTENT_PROJECT}}" --export-pack "$0 PCK" "{{.APP_DIR}}/bundles/$0.pck"'
```

9. Add the new bundle to the `build:bundles` deps list.

10. Add an export preset in `project/hosts/content-authoring/export_presets.cfg` for `"$0 PCK"`.

11. Commit with: `feat(bundles): scaffold $0 bundle`
