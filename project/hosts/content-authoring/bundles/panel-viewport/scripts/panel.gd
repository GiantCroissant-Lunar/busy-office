extends SubViewportContainer

var _doc: Node
var _sel: Node
var _viewport: SubViewport
var _canvas: Control
var _camera_offset := Vector2.ZERO
var _zoom := 1.0
var _panning := false

const TYPE_COLORS := {
	"Sprite2D": Color(0.3, 0.6, 1.0, 0.8),
	"ColorRect": Color(0.4, 0.8, 0.4, 0.8),
	"Label": Color(0.9, 0.5, 0.3, 0.8),
	"Node2D": Color(0.6, 0.6, 0.6, 0.8),
}
const DEFAULT_COLOR := Color(0.5, 0.5, 0.5, 0.8)
const NODE_SIZE := Vector2(80, 60)
const GRID_SIZE := 50.0


func _ready() -> void:
	_doc = get_node_or_null("/root/EditorDocument")
	_sel = get_node_or_null("/root/SelectionState")

	stretch = true
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL

	_viewport = SubViewport.new()
	_viewport.transparent_bg = true
	_viewport.handle_input_locally = false
	add_child(_viewport)

	_canvas = _ViewportCanvas.new()
	_canvas.viewport_panel = self
	_viewport.add_child(_canvas)

	if _doc:
		_doc.tree_changed.connect(_queue_redraw)
		_doc.node_property_changed.connect(_on_property_changed)
	if _sel:
		_sel.selection_changed.connect(_on_selection_changed)


func _queue_redraw() -> void:
	_canvas.queue_redraw()


func _on_property_changed(_id: String, _prop: String) -> void:
	_canvas.queue_redraw()


func _on_selection_changed(_id: String) -> void:
	_canvas.queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_MIDDLE:
			_panning = mb.pressed
		elif mb.button_index == MOUSE_BUTTON_WHEEL_UP and mb.pressed:
			_zoom = clampf(_zoom * 1.1, 0.1, 10.0)
			_canvas.queue_redraw()
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN and mb.pressed:
			_zoom = clampf(_zoom / 1.1, 0.1, 10.0)
			_canvas.queue_redraw()
		elif mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
			_handle_click(mb.position)

	elif event is InputEventMouseMotion:
		var mm := event as InputEventMouseMotion
		if _panning:
			_camera_offset += mm.relative / _zoom
			_canvas.queue_redraw()


func _handle_click(pos: Vector2) -> void:
	if not _doc or not _sel:
		return
	var world_pos := (pos / _zoom) - _camera_offset
	# Check nodes in reverse order (top-most first)
	var all_ids: Array = _doc.get_all_ids()
	all_ids.reverse()
	for id in all_ids:
		var data: Dictionary = _doc.get_node_data(id)
		if data.is_empty() or not data["visible"]:
			continue
		var node_pos: Vector2 = data["transform"]["position"]
		var node_scale: Vector2 = data["transform"]["scale"]
		var node_size := NODE_SIZE * node_scale.abs()
		# For ColorRect-like nodes, use scale as size
		if data["type"] == "ColorRect":
			node_size = node_scale.abs()
		var rect := Rect2(node_pos, node_size)
		if rect.has_point(world_pos):
			_sel.select(id)
			return
	_sel.clear()


class _ViewportCanvas extends Control:
	var viewport_panel: SubViewportContainer

	func _draw() -> void:
		var vp := viewport_panel
		var offset := vp._camera_offset
		var zoom := vp._zoom

		# Grid
		_draw_grid(offset, zoom)

		# Draw nodes
		if not vp._doc:
			return
		var all_ids: Array = vp._doc.get_all_ids()
		var selected_id := ""
		if vp._sel:
			selected_id = vp._sel.get_selected()

		for id in all_ids:
			var data: Dictionary = vp._doc.get_node_data(id)
			if data.is_empty() or not data["visible"]:
				continue
			var node_pos: Vector2 = data["transform"]["position"]
			var node_scale: Vector2 = data["transform"]["scale"]
			var node_size := NODE_SIZE * node_scale.abs()
			if data["type"] == "ColorRect":
				node_size = node_scale.abs()

			var screen_pos := (node_pos + offset) * zoom
			var screen_size := node_size * zoom

			var color: Color = TYPE_COLORS.get(data["type"], DEFAULT_COLOR)
			draw_rect(Rect2(screen_pos, screen_size), color)

			# Label
			var label_text: String = data["name"]
			if screen_size.x > 30 and screen_size.y > 15:
				draw_string(ThemeDB.fallback_font, screen_pos + Vector2(4, 14), label_text, HORIZONTAL_ALIGNMENT_LEFT, int(screen_size.x) - 8, 11, Color.WHITE)

			# Selection highlight
			if id == selected_id:
				draw_rect(Rect2(screen_pos, screen_size), Color.YELLOW, false, 2.0)

	func _draw_grid(offset: Vector2, zoom: float) -> void:
		var grid_color := Color(0.2, 0.2, 0.2)
		var w := size.x
		var h := size.y
		var step := GRID_SIZE * zoom

		if step < 5.0:
			return

		var start_x := fmod(offset.x * zoom, step)
		var start_y := fmod(offset.y * zoom, step)

		var x := start_x
		while x < w:
			draw_line(Vector2(x, 0), Vector2(x, h), grid_color, 1.0)
			x += step

		var y := start_y
		while y < h:
			draw_line(Vector2(0, y), Vector2(w, y), grid_color, 1.0)
			y += step
