class_name MultiStrokeInput
extends Node2D
## 여러 획 입력 ($Q용). 첫 손가락만 쓰고, UI가 먹은 터치는 받지 않는다(_unhandled_input).
## 손을 뗀 뒤 wait_time 동안 새 획이 없으면 glyph_finished. 두 손가락 동시 터치·앱 이탈·cancel()이면 취소.

signal glyph_started
signal glyph_finished(strokes: Array)
signal glyph_cancelled(reason: String)

@export var wait_time: float = 0.4
@export var line_width: float = 14.0
@export var line_color: Color = Color(1, 1, 1, 0.9)
@export var min_step: float = 4.0
@export var fade_time: float = 0.35

var strokes: Array = []  # 끝난 획들
var current := PackedVector2Array()
var drawing := false  # 손가락이 닿아 있음
var pending := false  # 글자를 그리는 중 (획 사이 대기 포함)
var _wait := 0.0
var _fade := 0.0
var _fade_color := Color.WHITE
var _fade_strokes: Array = []

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.index == 0 and event.pressed:
			begin_stroke(event.position)
		elif event.index == 0 and not event.pressed:
			if event.canceled:
				cancel("터치 취소")
			else:
				end_stroke()
		elif event.index != 0 and event.pressed and (drawing or pending):
			cancel("두 번째 손가락")
	elif event is InputEventScreenDrag and event.index == 0:
		add_point(event.position)

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_WM_WINDOW_FOCUS_OUT \
			or what == NOTIFICATION_APPLICATION_PAUSED:
		if drawing or pending:
			cancel("앱 전환")

func begin_stroke(pos: Vector2) -> void:
	if not pending:
		strokes.clear()
		_fade = 0.0
		glyph_started.emit()
	pending = true
	drawing = true
	current = PackedVector2Array([pos])
	queue_redraw()

func add_point(pos: Vector2) -> void:
	if drawing and current[current.size() - 1].distance_to(pos) >= min_step:
		current.append(pos)
		queue_redraw()

func end_stroke() -> void:
	if not drawing:
		return
	drawing = false
	if current.size() >= 2:
		strokes.append(current)
	current = PackedVector2Array()
	_wait = wait_time
	if strokes.is_empty():
		pending = false
	queue_redraw()

func cancel(reason: String) -> void:
	if not (drawing or pending):
		return
	drawing = false
	pending = false
	strokes.clear()
	current = PackedVector2Array()
	glyph_cancelled.emit(reason)
	queue_redraw()

func flash_result(color: Color) -> void:
	_fade_color = color
	_fade = fade_time

func _process(delta: float) -> void:
	if pending and not drawing:
		_wait -= delta
		if _wait <= 0.0:
			pending = false
			_fade_strokes = strokes.duplicate()
			var out := strokes.duplicate()
			strokes.clear()
			glyph_finished.emit(out)
		queue_redraw()
	if _fade > 0.0:
		_fade -= delta
		queue_redraw()

func _draw() -> void:
	for s in strokes:
		draw_polyline(s, line_color, line_width, true)
	if current.size() >= 2:
		draw_polyline(current, line_color, line_width, true)
	# 대기 표시: 마지막 획 끝에 줄어드는 원
	if pending and not drawing and not strokes.is_empty():
		var last: PackedVector2Array = strokes[strokes.size() - 1]
		var frac := clampf(_wait / wait_time, 0.0, 1.0)
		draw_arc(last[last.size() - 1], 26, -PI / 2, -PI / 2 + TAU * frac, 24, Color(1, 1, 1, 0.8), 6, true)
	if _fade > 0.0 and not pending:
		var c := _fade_color
		c.a = clampf(_fade / fade_time, 0.0, 1.0)
		for s in _fade_strokes:
			draw_polyline(s, c, line_width, true)
