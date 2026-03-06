extends VBoxContainer

var _playing: bool = false
var _looping: bool = true
var _current_frame: int = 0
var _total_frames: int = 120
var _fps: float = 24.0
var _elapsed: float = 0.0

var _frame_label: Label
var _fps_spin: SpinBox
var _keyframe_area: Control

# Demo tracks with hardcoded keyframes: track_name -> [frame, frame, ...]
var _tracks: Dictionary = {
	"Player/position": [0, 30, 60, 90, 120],
	"Player/rotation": [0, 60, 120],
	"Background/visible": [0, 50],
	"Title/position": [0, 40, 80, 120],
}


func _ready() -> void:
	# Transport bar
	var transport := HBoxContainer.new()
	transport.add_theme_constant_override("separation", 4)

	var play_btn := Button.new()
	play_btn.text = "Play"
	play_btn.pressed.connect(_on_play)
	transport.add_child(play_btn)

	var pause_btn := Button.new()
	pause_btn.text = "Pause"
	pause_btn.pressed.connect(_on_pause)
	transport.add_child(pause_btn)

	var stop_btn := Button.new()
	stop_btn.text = "Stop"
	stop_btn.pressed.connect(_on_stop)
	transport.add_child(stop_btn)

	var step_btn := Button.new()
	step_btn.text = "Step"
	step_btn.pressed.connect(_on_step)
	transport.add_child(step_btn)

	transport.add_child(VSeparator.new())

	_frame_label = Label.new()
	_frame_label.text = "0 / %d" % _total_frames
	_frame_label.custom_minimum_size.x = 80
	transport.add_child(_frame_label)

	transport.add_child(VSeparator.new())

	var fps_label := Label.new()
	fps_label.text = "FPS:"
	transport.add_child(fps_label)

	_fps_spin = SpinBox.new()
	_fps_spin.min_value = 1
	_fps_spin.max_value = 120
	_fps_spin.value = _fps
	_fps_spin.value_changed.connect(func(v: float) -> void: _fps = v)
	transport.add_child(_fps_spin)

	var loop_check := CheckBox.new()
	loop_check.text = "Loop"
	loop_check.button_pressed = _looping
	loop_check.toggled.connect(func(v: bool) -> void: _looping = v)
	transport.add_child(loop_check)

	add_child(transport)

	# Main split: track list (left) + keyframe area (right)
	var split := HSplitContainer.new()
	split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	split.split_offset = 150

	var track_list := VBoxContainer.new()
	track_list.custom_minimum_size.x = 150
	for track_name in _tracks:
		var lbl := Label.new()
		lbl.text = track_name
		lbl.add_theme_font_size_override("font_size", 12)
		track_list.add_child(lbl)
	split.add_child(track_list)

	_keyframe_area = _KeyframeArea.new()
	_keyframe_area.timeline_panel = self
	_keyframe_area.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_keyframe_area.size_flags_vertical = Control.SIZE_EXPAND_FILL
	split.add_child(_keyframe_area)

	add_child(split)


func _process(delta: float) -> void:
	if _playing:
		_elapsed += delta
		var frame_duration := 1.0 / _fps
		if _elapsed >= frame_duration:
			_elapsed -= frame_duration
			_current_frame += 1
			if _current_frame > _total_frames:
				if _looping:
					_current_frame = 0
				else:
					_current_frame = _total_frames
					_playing = false
			_frame_label.text = "%d / %d" % [_current_frame, _total_frames]
			_keyframe_area.queue_redraw()


func _on_play() -> void:
	_playing = true


func _on_pause() -> void:
	_playing = false


func _on_stop() -> void:
	_playing = false
	_current_frame = 0
	_elapsed = 0.0
	_frame_label.text = "0 / %d" % _total_frames
	_keyframe_area.queue_redraw()


func _on_step() -> void:
	_playing = false
	_current_frame = mini(_current_frame + 1, _total_frames)
	_frame_label.text = "%d / %d" % [_current_frame, _total_frames]
	_keyframe_area.queue_redraw()


class _KeyframeArea extends Control:
	var timeline_panel: VBoxContainer

	const TRACK_HEIGHT := 20.0
	const RULER_HEIGHT := 20.0
	const DIAMOND_SIZE := 6.0

	func _gui_input(event: InputEvent) -> void:
		if event is InputEventMouseButton:
			var mb := event as InputEventMouseButton
			if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
				var x := mb.position.x
				var frame := _x_to_frame(x)
				timeline_panel._current_frame = clampi(frame, 0, timeline_panel._total_frames)
				timeline_panel._frame_label.text = "%d / %d" % [timeline_panel._current_frame, timeline_panel._total_frames]
				queue_redraw()

	func _draw() -> void:
		var w := size.x
		var total := timeline_panel._total_frames
		var tracks: Dictionary = timeline_panel._tracks

		# Background
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.15, 0.15, 0.15))

		# Ruler
		draw_rect(Rect2(0, 0, w, RULER_HEIGHT), Color(0.2, 0.2, 0.2))
		var step := 10
		for f in range(0, total + 1, step):
			var x := _frame_to_x(f)
			draw_line(Vector2(x, 0), Vector2(x, RULER_HEIGHT), Color(0.5, 0.5, 0.5), 1.0)
			if f % 30 == 0:
				draw_string(ThemeDB.fallback_font, Vector2(x + 2, 14), str(f), HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0.7, 0.7, 0.7))

		# Track rows + keyframe diamonds
		var track_idx := 0
		for track_name in tracks:
			var y := RULER_HEIGHT + track_idx * TRACK_HEIGHT + TRACK_HEIGHT * 0.5
			# Row separator
			draw_line(Vector2(0, RULER_HEIGHT + track_idx * TRACK_HEIGHT), Vector2(w, RULER_HEIGHT + track_idx * TRACK_HEIGHT), Color(0.25, 0.25, 0.25), 1.0)
			# Keyframes
			var frames: Array = tracks[track_name]
			for f in frames:
				var x := _frame_to_x(f)
				_draw_diamond(Vector2(x, y), DIAMOND_SIZE, Color(0.9, 0.7, 0.2))
			track_idx += 1

		# Playhead (red vertical line)
		var ph_x := _frame_to_x(timeline_panel._current_frame)
		draw_line(Vector2(ph_x, 0), Vector2(ph_x, size.y), Color(1, 0, 0), 2.0)

	func _draw_diamond(center: Vector2, half_size: float, color: Color) -> void:
		var points := PackedVector2Array([
			center + Vector2(0, -half_size),
			center + Vector2(half_size, 0),
			center + Vector2(0, half_size),
			center + Vector2(-half_size, 0),
		])
		draw_colored_polygon(points, color)

	func _frame_to_x(frame: int) -> float:
		var total := timeline_panel._total_frames
		if total == 0:
			return 0.0
		return (float(frame) / float(total)) * size.x

	func _x_to_frame(x: float) -> int:
		var total := timeline_panel._total_frames
		if size.x == 0:
			return 0
		return roundi((x / size.x) * float(total))
