extends ScrollContainer

var _doc: Node
var _sel: Node
var _updating: bool = false
var _current_id: String = ""

var _vbox: VBoxContainer
var _no_selection_label: Label
var _name_edit: LineEdit
var _type_label: Label
var _visible_check: CheckBox
var _pos_x: SpinBox
var _pos_y: SpinBox
var _rotation_spin: SpinBox
var _scale_x: SpinBox
var _scale_y: SpinBox
var _props_container: VBoxContainer


func _ready() -> void:
	_doc = get_node_or_null("/root/EditorDocument")
	_sel = get_node_or_null("/root/SelectionState")

	_vbox = VBoxContainer.new()
	_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(_vbox)

	_no_selection_label = Label.new()
	_no_selection_label.text = "No node selected"
	_no_selection_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_vbox.add_child(_no_selection_label)

	# Name
	_vbox.add_child(_make_label("Name"))
	_name_edit = LineEdit.new()
	_name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_name_edit.text_submitted.connect(_on_name_changed)
	_vbox.add_child(_name_edit)

	# Type
	_vbox.add_child(_make_label("Type"))
	_type_label = Label.new()
	_vbox.add_child(_type_label)

	# Visible
	_visible_check = CheckBox.new()
	_visible_check.text = "Visible"
	_visible_check.toggled.connect(_on_visible_toggled)
	_vbox.add_child(_visible_check)

	# Separator
	_vbox.add_child(HSeparator.new())
	_vbox.add_child(_make_label("Transform"))

	# Position
	var pos_hbox := _make_vector_row("Position")
	_pos_x = pos_hbox.get_child(1)
	_pos_y = pos_hbox.get_child(2)
	_pos_x.value_changed.connect(_on_position_changed)
	_pos_y.value_changed.connect(_on_position_changed)
	_vbox.add_child(pos_hbox)

	# Rotation
	var rot_hbox := HBoxContainer.new()
	rot_hbox.add_child(_make_label("Rotation"))
	_rotation_spin = _make_spin_box(-360, 360, 0.1)
	_rotation_spin.value_changed.connect(_on_rotation_changed)
	rot_hbox.add_child(_rotation_spin)
	_vbox.add_child(rot_hbox)

	# Scale
	var scale_hbox := _make_vector_row("Scale")
	_scale_x = scale_hbox.get_child(1)
	_scale_y = scale_hbox.get_child(2)
	_scale_x.value_changed.connect(_on_scale_changed)
	_scale_y.value_changed.connect(_on_scale_changed)
	_vbox.add_child(scale_hbox)

	# Separator + custom props
	_vbox.add_child(HSeparator.new())
	_vbox.add_child(_make_label("Properties"))
	_props_container = VBoxContainer.new()
	_vbox.add_child(_props_container)

	if _sel:
		_sel.selection_changed.connect(_on_selection_changed)
	if _doc:
		_doc.node_property_changed.connect(_on_property_changed_external)

	_show_no_selection()


func _make_label(text: String) -> Label:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", 12)
	return lbl


func _make_spin_box(min_val: float, max_val: float, step: float) -> SpinBox:
	var sb := SpinBox.new()
	sb.min_value = min_val
	sb.max_value = max_val
	sb.step = step
	sb.allow_greater = true
	sb.allow_lesser = true
	sb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return sb


func _make_vector_row(label_text: String) -> HBoxContainer:
	var hbox := HBoxContainer.new()
	hbox.add_child(_make_label(label_text))
	var x := _make_spin_box(-10000, 10000, 1.0)
	var y := _make_spin_box(-10000, 10000, 1.0)
	x.prefix = "X"
	y.prefix = "Y"
	hbox.add_child(x)
	hbox.add_child(y)
	return hbox


func _show_no_selection() -> void:
	_no_selection_label.visible = true
	for i in range(1, _vbox.get_child_count()):
		_vbox.get_child(i).visible = false


func _show_inspector() -> void:
	_no_selection_label.visible = false
	for i in range(1, _vbox.get_child_count()):
		_vbox.get_child(i).visible = true


func _on_selection_changed(node_id: String) -> void:
	_current_id = node_id
	if node_id == "":
		_show_no_selection()
		return
	_refresh()


func _refresh() -> void:
	if not _doc or _current_id == "":
		return
	var data: Dictionary = _doc.get_node_data(_current_id)
	if data.is_empty():
		_show_no_selection()
		return

	_show_inspector()
	_updating = true

	_name_edit.text = data["name"]
	_type_label.text = data["type"]
	_visible_check.button_pressed = data["visible"]

	var t: Dictionary = data["transform"]
	var pos: Vector2 = t["position"]
	_pos_x.value = pos.x
	_pos_y.value = pos.y
	_rotation_spin.value = t["rotation"]
	var s: Vector2 = t["scale"]
	_scale_x.value = s.x
	_scale_y.value = s.y

	# Custom properties
	for child in _props_container.get_children():
		child.queue_free()
	var props: Dictionary = data["properties"]
	for key in props:
		var hbox := HBoxContainer.new()
		hbox.add_child(_make_label(key))
		var val_label := Label.new()
		val_label.text = str(props[key])
		val_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hbox.add_child(val_label)
		_props_container.add_child(hbox)

	_updating = false


func _on_name_changed(new_name: String) -> void:
	if _updating or not _doc or _current_id == "":
		return
	_doc.set_property(_current_id, "name", new_name)


func _on_visible_toggled(pressed: bool) -> void:
	if _updating or not _doc or _current_id == "":
		return
	_doc.set_property(_current_id, "visible", pressed)


func _on_position_changed(_value: float) -> void:
	if _updating or not _doc or _current_id == "":
		return
	_doc.set_property(_current_id, "position", Vector2(_pos_x.value, _pos_y.value))


func _on_rotation_changed(value: float) -> void:
	if _updating or not _doc or _current_id == "":
		return
	_doc.set_property(_current_id, "rotation", value)


func _on_scale_changed(_value: float) -> void:
	if _updating or not _doc or _current_id == "":
		return
	_doc.set_property(_current_id, "scale", Vector2(_scale_x.value, _scale_y.value))


func _on_property_changed_external(id: String, _prop_name: String) -> void:
	if id == _current_id and not _updating:
		_refresh()
