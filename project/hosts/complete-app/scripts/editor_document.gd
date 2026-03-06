extends Node

signal tree_changed()
signal node_added(id: String)
signal node_removed(id: String)
signal node_property_changed(id: String, prop_name: String)

var _nodes: Dictionary = {}
var _next_id: int = 1


func _ready() -> void:
	_create_demo_scene()


func _create_demo_scene() -> void:
	var root_id := add_node("Root", "Node2D", "", Vector2(960, 540), 0.0, Vector2.ONE, true)
	add_node("Player", "Sprite2D", root_id, Vector2(200, 300), 0.0, Vector2(1.5, 1.5), true)
	add_node("Background", "ColorRect", root_id, Vector2(0, 0), 0.0, Vector2(1920, 1080), true)
	add_node("Title", "Label", root_id, Vector2(800, 50), 0.0, Vector2.ONE, true)


func add_node(node_name: String, type: String, parent_id: String, position := Vector2.ZERO, rotation := 0.0, scale := Vector2.ONE, visible := true) -> String:
	var id := str(_next_id)
	_next_id += 1
	_nodes[id] = {
		"id": id,
		"name": node_name,
		"type": type,
		"parent_id": parent_id,
		"transform": {
			"position": position,
			"rotation": rotation,
			"scale": scale,
		},
		"visible": visible,
		"properties": {},
	}
	node_added.emit(id)
	tree_changed.emit()
	return id


func remove_node(id: String) -> void:
	if not _nodes.has(id):
		return
	var children := get_children_ids(id)
	for child_id in children:
		remove_node(child_id)
	_nodes.erase(id)
	node_removed.emit(id)
	tree_changed.emit()


func get_node_data(id: String) -> Dictionary:
	if _nodes.has(id):
		return _nodes[id]
	return {}


func set_property(id: String, prop_name: String, value: Variant) -> void:
	if not _nodes.has(id):
		return
	var node_data: Dictionary = _nodes[id]
	match prop_name:
		"name":
			node_data["name"] = value
		"visible":
			node_data["visible"] = value
		"position":
			node_data["transform"]["position"] = value
		"rotation":
			node_data["transform"]["rotation"] = value
		"scale":
			node_data["transform"]["scale"] = value
		_:
			node_data["properties"][prop_name] = value
	node_property_changed.emit(id, prop_name)


func get_children_ids(parent_id: String) -> Array:
	var result: Array = []
	for id in _nodes:
		var node_data: Dictionary = _nodes[id]
		if node_data["parent_id"] == parent_id:
			result.append(id)
	return result


func get_root_id() -> String:
	for id in _nodes:
		var node_data: Dictionary = _nodes[id]
		if node_data["parent_id"] == "":
			return id
	return ""


func get_node_count() -> int:
	return _nodes.size()


func get_all_ids() -> Array:
	return _nodes.keys()


func duplicate_node(id: String) -> String:
	if not _nodes.has(id):
		return ""
	var source: Dictionary = _nodes[id]
	var transform: Dictionary = source["transform"]
	var new_id := add_node(
		source["name"] + " (Copy)",
		source["type"],
		source["parent_id"],
		transform["position"] + Vector2(20, 20),
		transform["rotation"],
		transform["scale"],
		source["visible"],
	)
	var new_data: Dictionary = _nodes[new_id]
	for key in source["properties"]:
		new_data["properties"][key] = source["properties"][key]
	return new_id


func reparent_node(id: String, new_parent_id: String) -> void:
	if not _nodes.has(id):
		return
	if id == new_parent_id:
		return
	var node_data: Dictionary = _nodes[id]
	node_data["parent_id"] = new_parent_id
	tree_changed.emit()
