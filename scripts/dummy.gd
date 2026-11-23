class_name Dummy
extends Node2D
## 시험용 허수아비 과녁. 맞으면 속성 색으로 번쩍이고 피해 숫자를 띄운다.
## 피해 숫자는 노드를 만들지 않고 배열로 그린다 (생성·삭제 없음).

@export var radius: float = 90.0
@export var float_time: float = 0.8

var total_damage := 0.0
var hits := 0
var _flash := 0.0
var _flash_color := Color.WHITE
var _texts: Array = []  # [{text, color, t, x}]

func _ready() -> void:
	add_to_group("targets")

func is_targetable() -> bool:
	return true

func take_hit(damage: float, element: int, empowered: bool, _base_damage: float) -> void:
	total_damage += damage
	hits += 1
	_flash = 0.15
	_flash_color = Element.color_of(element)
	var txt := str(int(damage))
	if empowered:
		txt += "!"
	_texts.append({"text": txt, "color": _flash_color, "t": 0.0, "x": randf_range(-50, 50)})
	if _texts.size() > 12:
		_texts.pop_front()

func reset_stats() -> void:
	total_damage = 0.0
	hits = 0

func _process(delta: float) -> void:
	_flash = maxf(_flash - delta, 0.0)
	for t in _texts:
		t.t += delta
	while _texts.size() > 0 and _texts[0].t >= float_time:
		_texts.pop_front()
	queue_redraw()

func _draw() -> void:
	var body := Color(0.55, 0.42, 0.3)
	if _flash > 0.0:
		body = body.lerp(_flash_color, 0.8)
	draw_rect(Rect2(-12, 0, 24, radius * 2.2), Color(0.4, 0.3, 0.2))
	draw_circle(Vector2.ZERO, radius, body)
	draw_arc(Vector2.ZERO, radius * 0.66, 0, TAU, 32, Color(0.9, 0.9, 0.85), 8)
	draw_arc(Vector2.ZERO, radius * 0.3, 0, TAU, 32, Color(0.9, 0.3, 0.25), 8)
	var font := UI.font()
	for t in _texts:
		var c: Color = t.color
		c.a = 1.0 - t.t / float_time
		var pos := Vector2(t.x - 30, -radius - 20 - t.t * 120.0)
		draw_string(font, pos, t.text, HORIZONTAL_ALIGNMENT_CENTER, 60, 44, c)
	draw_string(font, Vector2(-200, radius * 2.2 + 70), "피해 합계 %d  (%d회)" % [int(total_damage), hits],
		HORIZONTAL_ALIGNMENT_CENTER, 400, 36, Color(0.9, 0.9, 0.9))
