extends Tree

var _doc: Node
var _sel: Node
var _updating_selection: bool = false
var _id_to_item: Dictionary = {}
var _context_menu: PopupMenu

enum ContextItem { ADD_CHILD, DELETE, RENAME, DUPLICATE }


func _ready() -> void:
	_doc = get_node_or_null("/root/EditorDocument")
	_sel = get_node_or_null("/root/SelectionState")

	_context_menu = PopupMenu.new()
	_context_menu.add_item("Add Child", ContextItem.ADD_CHILD)
	_context_menu.add_item("Delete", ContextItem.DELETE)
	_context_menu.add_item("Rename", ContextItem.RENAME)
	_context_menu.add_item("Duplicate", ContextItem.DUPLICATE)
	_context_menu.id_pressed.connect(_on_context_item)
	add_child(_context_menu)

	item_selected.connect(_on_item_selected)

	if _doc:
		_doc.tree_changed.connect(_rebuild_tree)
		_rebuild_tree()

	if _sel:
		_sel.selection_changed.connect(_on_external_selection)


func _rebuild_tree() -> void:
	_updating_selection = true
	_id_to_item.clear()
	clear()

	if not _doc:
		_updating_selection = false
		return

	var root_id: String = _doc.get_root_id()
	if root_id == "":
		_updating_selection = false
		return

	var root_data: Dictionary = _doc.get_node_data(root_id)
	var root_item := create_item()
	root_item.set_text(0, "%s (%s)" % [root_data["name"], root_data["type"]])
	root_item.set_metadata(0, root_id)
	_id_to_item[root_id] = root_item

	_build_children(root_id, root_item)

	# Restore selection
	if _sel:
		var selected_id: String = _sel.get_selected()
		if selected_id != "" and _id_to_item.has(selected_id):
			_id_to_item[selected_id].select(0)

	_updating_selection = false


func _build_children(parent_id: String, parent_item: TreeItem) -> void:
	var children: Array = _doc.get_children_ids(parent_id)
	for child_id in children:
		var data: Dictionary = _doc.get_node_data(child_id)
		var item := create_item(parent_item)
		item.set_text(0, "%s (%s)" % [data["name"], data["type"]])
		item.set_metadata(0, child_id)
		_id_to_item[child_id] = item
		_build_children(child_id, item)


func _on_item_selected() -> void:
	if _updating_selection:
		return
	var item := get_selected()
	if item and _sel:
		_updating_selection = true
		_sel.select(item.get_metadata(0))
		_updating_selection = false


func _on_external_selection(node_id: String) -> void:
	if _updating_selection:
		return
	_updating_selection = true
	if node_id != "" and _id_to_item.has(node_id):
		_id_to_item[node_id].select(0)
	else:
		deselect_all()
	_updating_selection = false


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_RIGHT and mb.pressed:
			_context_menu.position = Vector2i(get_global_mouse_position())
			_context_menu.popup()


func _on_context_item(id: int) -> void:
	if not _doc or not _sel:
		return
	var selected_id: String = _sel.get_selected()
	match id:
		ContextItem.ADD_CHILD:
			var parent_id := selected_id if selected_id != "" else _doc.get_root_id()
			var new_id: String = _doc.add_node("NewNode", "Node2D", parent_id)
			_sel.select(new_id)
		ContextItem.DELETE:
			if selected_id != "" and selected_id != _doc.get_root_id():
				_sel.clear()
				_doc.remove_node(selected_id)
		ContextItem.RENAME:
			pass  # placeholder
		ContextItem.DUPLICATE:
			if selected_id != "" and selected_id != _doc.get_root_id():
				var new_id: String = _doc.duplicate_node(selected_id)
				if new_id != "":
					_sel.select(new_id)
