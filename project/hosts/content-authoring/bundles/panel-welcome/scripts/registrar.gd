extends Node

const PANEL_ID := "welcome"
const PANEL_TITLE := "Welcome"
const PANEL_ZONE := 1  # Center
const PANEL_SCENE := "res://bundles/panel-welcome/scenes/panel.tscn"


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
