extends PanelContainer

var _label: Label


func _ready() -> void:
	_label = Label.new()
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(_label)
	_update_text()


func _process(_delta: float) -> void:
	_update_text()


func _update_text() -> void:
	var ts := Time.get_datetime_string_from_system(false, true)
	_label.text = "Welcome to Busy Office!\n\nCurrent time: %s" % ts
