extends Node

signal selection_changed(node_id: String)

var _selected_id: String = ""


func select(node_id: String) -> void:
	if _selected_id != node_id:
		_selected_id = node_id
		selection_changed.emit(node_id)


func clear() -> void:
	select("")


func get_selected() -> String:
	return _selected_id
