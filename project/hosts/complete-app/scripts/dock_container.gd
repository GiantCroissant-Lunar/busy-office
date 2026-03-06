extends VSplitContainer

# Maps DockZone enum values to TabContainer node paths
# DockZone: Left=0, Center=1, Right=2, BottomLeft=3, BottomRight=4, Bottom=5
var _zone_map: Dictionary = {}
var _panels: Dictionary = {}  # panelId -> { node, zone, title }


func _ready() -> void:
	_zone_map[0] = $MainArea/LeftColumn/LeftTop       # DockZone.Left
	_zone_map[1] = $MainArea/Center                    # DockZone.Center
	_zone_map[2] = $MainArea/RightColumn/RightTop      # DockZone.Right
	_zone_map[3] = $MainArea/LeftColumn/LeftBottom      # DockZone.BottomLeft
	_zone_map[4] = $MainArea/RightColumn/RightBottom    # DockZone.BottomRight
	_zone_map[5] = $Bottom                              # DockZone.Bottom


func register_panel(panel_id: String, title: String, content_node: Node, zone: int) -> void:
	if _panels.has(panel_id):
		unregister_panel(panel_id)

	var tab_container: TabContainer = _zone_map.get(zone, _zone_map[1])

	var panel: Control
	if content_node != null:
		panel = content_node
	else:
		panel = _create_placeholder(title)

	panel.name = title
	tab_container.add_child(panel)

	_panels[panel_id] = { "node": panel, "zone": zone, "title": title }


func unregister_panel(panel_id: String) -> void:
	if not _panels.has(panel_id):
		return

	var info: Dictionary = _panels[panel_id]
	var node: Node = info["node"]
	if is_instance_valid(node):
		node.get_parent().remove_child(node)
		node.queue_free()

	_panels.erase(panel_id)


func move_panel(panel_id: String, target_zone: int) -> void:
	if not _panels.has(panel_id):
		return

	var info: Dictionary = _panels[panel_id]
	var node: Control = info["node"]
	var old_parent := node.get_parent()

	old_parent.remove_child(node)

	var new_container: TabContainer = _zone_map.get(target_zone, _zone_map[1])
	new_container.add_child(node)

	info["zone"] = target_zone


func _create_placeholder(title: String) -> Control:
	var panel := PanelContainer.new()
	var label := Label.new()
	label.text = title
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	panel.add_child(label)
	return panel
