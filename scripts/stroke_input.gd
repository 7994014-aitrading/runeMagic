class_name StrokeInput
extends Node2D
## 한 획 입력. 첫 손가락만 쓰고, UI가 먹은 터치는 받지 않는다(_unhandled_input).
## 두 번째 손가락, 앱 포커스 이탈, cancel() 호출 시 진행 중인 획을 취소한다.

signal stroke_started
signal stroke_finished(points: PackedVector2Array)
signal stroke_cancelled(reason: String)

@export var line_width: float = 14.0
@export var line_color: Color = Color(1, 1, 1, 0.9)
@export var min_step: float = 4.0  # 이 거리보다 가까운 점은 버림
@export var fade_time: float = 0.35  # 손 뗀 뒤 선이 사라지는 시간

var drawing := false
var points := PackedVector2Array()
var _fade := 0.0
var _fade_color := Color.WHITE

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.index == 0 and event.pressed:
			begin(event.position)
		elif event.index == 0 and not event.pressed:
			if event.canceled:
				cancel("터치 취소")
			else:
				finish()
		elif event.index != 0 and event.pressed and drawing:
			cancel("두 번째 손가락")
	elif event is InputEventScreenDrag and event.index == 0:
		add_point(event.position)

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_WM_WINDOW_FOCUS_OUT \
			or what == NOTIFICATION_APPLICATION_PAUSED:
		if drawing:
			cancel("앱 전환")

func begin(pos: Vector2) -> void:
	drawing = true
	_fade = 0.0
	points = PackedVector2Array([pos])
	stroke_started.emit()
	queue_redraw()

func add_point(pos: Vector2) -> void:
	if not drawing:
		return
	if points[points.size() - 1].distance_to(pos) >= min_step:
		points.append(pos)
		queue_redraw()

func finish() -> void:
	if not drawing:
		return
	drawing = false
	stroke_finished.emit(points)

func cancel(reason: String) -> void:
	if not drawing:
		return
	drawing = false
	points = PackedVector2Array()
	stroke_cancelled.emit(reason)
	queue_redraw()

## 판정 결과 색으로 잠깐 남겼다가 사라지게 한다.
func flash_result(color: Color) -> void:
	_fade_color = color
	_fade = fade_time

func _process(delta: float) -> void:
	if _fade > 0.0:
		_fade -= delta
		if _fade <= 0.0:
			points = PackedVector2Array()
		queue_redraw()

func _draw() -> void:
	if points.size() < 2:
		return
	var c := line_color
	if not drawing:
		c = _fade_color
		c.a = clampf(_fade / fade_time, 0.0, 1.0)
	draw_polyline(points, c, line_width, true)
