extends MenuBar

var _file_popup: PopupMenu
var _edit_popup: PopupMenu
var _view_popup: PopupMenu
var _help_popup: PopupMenu

enum FileItem { NEW, OPEN, SAVE, EXIT = 10 }
enum EditItem { UNDO, REDO, DELETE = 5, DUPLICATE }
enum ViewItem { SHOW_GRID }
enum HelpItem { ABOUT }


func _ready() -> void:
	_file_popup = PopupMenu.new()
	_file_popup.name = "File"
	_file_popup.add_item("New Scene", FileItem.NEW)
	_file_popup.add_item("Open...", FileItem.OPEN)
	_file_popup.add_item("Save", FileItem.SAVE)
	_file_popup.add_separator()
	_file_popup.add_item("Exit", FileItem.EXIT)
	_file_popup.id_pressed.connect(_on_file_item)
	add_child(_file_popup)

	_edit_popup = PopupMenu.new()
	_edit_popup.name = "Edit"
	_edit_popup.add_item("Undo", EditItem.UNDO)
	_edit_popup.add_item("Redo", EditItem.REDO)
	_edit_popup.add_separator()
	_edit_popup.add_item("Delete", EditItem.DELETE)
	_edit_popup.add_item("Duplicate", EditItem.DUPLICATE)
	_edit_popup.id_pressed.connect(_on_edit_item)
	add_child(_edit_popup)

	_view_popup = PopupMenu.new()
	_view_popup.name = "View"
	_view_popup.add_check_item("Show Grid", ViewItem.SHOW_GRID)
	_view_popup.id_pressed.connect(_on_view_item)
	add_child(_view_popup)

	_help_popup = PopupMenu.new()
	_help_popup.name = "Help"
	_help_popup.add_item("About", HelpItem.ABOUT)
	_help_popup.id_pressed.connect(_on_help_item)
	add_child(_help_popup)


func _on_file_item(id: int) -> void:
	match id:
		FileItem.NEW:
			pass  # placeholder
		FileItem.OPEN:
			pass  # placeholder
		FileItem.SAVE:
			pass  # placeholder
		FileItem.EXIT:
			get_tree().quit()


func _on_edit_item(id: int) -> void:
	var doc: Node = get_node_or_null("/root/EditorDocument")
	var sel: Node = get_node_or_null("/root/SelectionState")
	if not doc or not sel:
		return
	var selected_id: String = sel.get_selected()
	match id:
		EditItem.DELETE:
			if selected_id != "" and selected_id != doc.get_root_id():
				sel.clear()
				doc.remove_node(selected_id)
		EditItem.DUPLICATE:
			if selected_id != "" and selected_id != doc.get_root_id():
				var new_id: String = doc.duplicate_node(selected_id)
				if new_id != "":
					sel.select(new_id)


func _on_view_item(id: int) -> void:
	match id:
		ViewItem.SHOW_GRID:
			var idx := _view_popup.get_item_index(ViewItem.SHOW_GRID)
			_view_popup.set_item_checked(idx, not _view_popup.is_item_checked(idx))


func _on_help_item(id: int) -> void:
	match id:
		HelpItem.ABOUT:
			pass  # placeholder
