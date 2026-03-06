extends HBoxContainer

var _selection_label: Label
var _count_label: Label
var _fps_label: Label


func _ready() -> void:
	add_theme_constant_override("separation", 20)

	_selection_label = Label.new()
	_selection_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_selection_label.text = "No selection"
	add_child(_selection_label)

	_count_label = Label.new()
	_count_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_count_label)

	_fps_label = Label.new()
	_fps_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_fps_label.custom_minimum_size.x = 80
	add_child(_fps_label)

	var sel: Node = get_node_or_null("/root/SelectionState")
	if sel:
		sel.selection_changed.connect(_on_selection_changed)

	var doc: Node = get_node_or_null("/root/EditorDocument")
	if doc:
		doc.tree_changed.connect(_on_tree_changed)
		_update_count(doc)


func _process(_delta: float) -> void:
	_fps_label.text = "FPS: %d" % Engine.get_frames_per_second()


func _on_selection_changed(node_id: String) -> void:
	if node_id == "":
		_selection_label.text = "No selection"
		return
	var doc: Node = get_node_or_null("/root/EditorDocument")
	if doc:
		var data: Dictionary = doc.get_node_data(node_id)
		if data.size() > 0:
			_selection_label.text = "Selected: %s (%s)" % [data["name"], data["type"]]
		else:
			_selection_label.text = "No selection"


func _on_tree_changed() -> void:
	var doc: Node = get_node_or_null("/root/EditorDocument")
	if doc:
		_update_count(doc)


func _update_count(doc: Node) -> void:
	_count_label.text = "Nodes: %d" % doc.get_node_count()
