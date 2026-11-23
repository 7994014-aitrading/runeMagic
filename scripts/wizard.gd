class_name Wizard
extends Node2D
## 마법사: 기본 공격 자동 발사 + 속성 칸 관리 + 강화탄 예약.
## 속성 칸은 목록 구조(slots). 칸 수는 config.slot_count (MVP는 1).

@export var config: RuneConfig
@export var projectile_parent: Node2D

var slots: Array = []  # [{element, time_left, duration}]
var empower_element := Element.NONE
var _fire_index := 0
var _cooldown := 0.0
var _pool: Array[Projectile] = []
var _t := 0.0
var _frames: Array = []  # 뒷모습 대기 프레임 (없으면 도형)
const SPRITE_SCALE := 1.6
const FOOT_Y := 60.0  # 발이 닿는 로컬 y
const TIP := Vector2(57, -92)  # 그림 속 지팡이 수정 위치 (속성 빛)

var _body: Node2D  # 그림만 (스킨 색 변형 재질)
var _glow: Node2D  # 지팡이 빛 (재질 영향 없이 그림 위에)

func _ready() -> void:
	_frames = Art.wizard_frames("north")
	_body = Node2D.new()
	_body.material = UI.skin_material(GameState.skin())
	_body.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(_body)
	_body.draw.connect(_draw_body)
	_glow = Node2D.new()
	add_child(_glow)
	_glow.draw.connect(_draw_glow)
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	for i in config.slot_count:
		slots.append({"element": Element.NONE, "time_left": 0.0, "duration": 1.0})
	for i in config.pool_size:
		var p := Projectile.new()
		p.visible = false
		projectile_parent.add_child(p)
		_pool.append(p)

func clear_slots() -> void:
	for s in slots:
		s.element = Element.NONE
		s.time_left = 0.0
	empower_element = Element.NONE

func remaining_of(e: int) -> float:
	for s in slots:
		if s.element == e:
			return s.time_left
	return 0.0

## debug: change slot count (keeps existing slots, drops extras)
func set_slot_count(n: int) -> void:
	while slots.size() < n:
		slots.append({"element": Element.NONE, "time_left": 0.0, "duration": 1.0})
	while slots.size() > n:
		slots.pop_back()
	_fire_index %= slots.size()

## 룬 적용. 반환: "refresh"(같은 속성 갱신) / "new"(빈 칸) / "replace"(교체)
func apply_rune(element: int, tier: String) -> String:
	var dur := config.duration_for(tier)
	for s in slots:
		if s.element == element:
			s.time_left = dur
			s.duration = dur
			return "refresh"
	var kind := "new"
	var target = null
	for s in slots:
		if s.element == Element.NONE:
			target = s
			break
	if target == null:
		kind = "replace"
		target = slots[0]
		for s in slots:
			if s.time_left < target.time_left:
				target = s
	target.element = element
	target.time_left = dur
	target.duration = dur
	if tier == "perfect":
		empower_element = element  # 예약은 1발, 덮어쓰기
	return kind

func _process(delta: float) -> void:
	for s in slots:
		if s.element != Element.NONE:
			s.time_left -= delta
			if s.time_left <= 0.0:
				s.element = Element.NONE
				s.time_left = 0.0
	if empower_element != Element.NONE and not _has_element(empower_element):
		empower_element = Element.NONE
	_t += delta
	_cooldown -= delta
	if _cooldown <= 0.0:
		var tgt := _nearest_target()
		if tgt != null:
			_fire(tgt)
			_cooldown = config.fire_interval
	queue_redraw()

func _has_element(e: int) -> bool:
	for s in slots:
		if s.element == e:
			return true
	return false

func _nearest_target() -> Node2D:
	var best: Node2D = null
	var best_d := INF
	for t in get_tree().get_nodes_in_group("targets"):
		var d := global_position.distance_squared_to(t.global_position)
		if d < best_d:
			best_d = d
			best = t
	return best

## 칸 순번대로 다음 속성. 빈 칸은 건너뛰고, 순번은 갱신해도 초기화하지 않는다.
func _next_element() -> int:
	for k in slots.size():
		var idx := (_fire_index + k) % slots.size()
		if slots[idx].element != Element.NONE:
			_fire_index = (idx + 1) % slots.size()
			return slots[idx].element
	return Element.NONE

func _fire(tgt: Node2D) -> void:
	var p: Projectile = null
	for q in _pool:
		if not q.active:
			p = q
			break
	if p == null:
		return
	var e := _next_element()
	var emp := e != Element.NONE and e == empower_element
	var dmg := config.base_damage * (config.empowered_multiplier if emp else 1.0)
	if emp:
		empower_element = Element.NONE
	p.launch(global_position + (TIP if not _frames.is_empty() else Vector2(0, -110)), tgt, e, dmg, config.projectile_speed, emp, config.base_damage)

func _draw() -> void:
	if not _frames.is_empty():
		_draw_sprite()
	else:
		_draw_shapes()
	_draw_gauges()

func _draw_sprite() -> void:
	var tex: Texture2D = _frames[int(_t * 12.0) % _frames.size()]
	var size := Vector2(tex.get_width(), tex.get_height()) * SPRITE_SCALE
	var foot := size.y * 140.0 / 164.0
	draw_set_transform(Vector2(0, FOOT_Y), 0.0, Vector2(1.0, 0.3))
	draw_circle(Vector2.ZERO, size.x * 0.25, Color(0, 0, 0, 0.35))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	_body.queue_redraw()
	_glow.queue_redraw()

func _draw_body() -> void:
	if _frames.is_empty():
		return
	var tex: Texture2D = _frames[int(_t * 12.0) % _frames.size()]
	var size := Vector2(tex.get_width(), tex.get_height()) * SPRITE_SCALE
	var foot := size.y * 140.0 / 164.0
	_body.draw_texture_rect(tex, Rect2(Vector2(-size.x / 2.0, FOOT_Y - foot), size), false)

func _draw_glow() -> void:
	var tip := _tip_element()
	if _frames.is_empty() or tip == Element.NONE:
		return
	var c := Element.color_of(tip)
	var pulse := 0.5 + 0.5 * sin(_t * 6.0)
	_glow.draw_circle(TIP, 30.0 + 6.0 * pulse, Color(c, 0.25))
	_glow.draw_circle(TIP, 15.0, Color(c, 0.75))
	_glow.draw_circle(TIP, 6.0, Color(1, 1, 1, 0.9))

func _tip_element() -> int:
	for s in slots:
		if s.element != Element.NONE:
			return s.element
	return Element.NONE

func _draw_shapes() -> void:
	# 몸
	draw_colored_polygon(PackedVector2Array([Vector2(-70, 60), Vector2(70, 60), Vector2(0, -80)]), Color(0.45, 0.3, 0.75))
	draw_circle(Vector2(0, -95), 34, Color(0.95, 0.85, 0.7))
	draw_colored_polygon(PackedVector2Array([Vector2(-50, -110), Vector2(50, -110), Vector2(0, -200)]), Color(0.35, 0.22, 0.6))
	# 지팡이 끝: 현재 다음 발 속성 색
	var tip := Element.NONE
	for s in slots:
		if s.element != Element.NONE:
			tip = s.element
			break
	draw_line(Vector2(60, 40), Vector2(60, -110), Color(0.5, 0.35, 0.2), 8)
	draw_circle(Vector2(60, -118), 16, Element.color_of(tip))

func _draw_gauges() -> void:
	# 칸 게이지
	var font := UI.font()
	var w := 420.0
	for i in slots.size():
		var s: Dictionary = slots[i]
		var y := 110.0 + i * 70.0
		draw_rect(Rect2(-w / 2, y, w, 34), Color(0.2, 0.2, 0.25))
		if s.element != Element.NONE:
			var frac := clampf(s.time_left / s.duration, 0.0, 1.0)
			draw_rect(Rect2(-w / 2, y, w * frac, 34), Element.color_of(s.element))
			var label := "%s  %.1f초" % [Element.name_of(s.element), s.time_left]
			if empower_element == s.element:
				label += "  강화탄 준비"
			draw_string_outline(font, Vector2(-w / 2, y + 27), label, HORIZONTAL_ALIGNMENT_CENTER, w, 26, 6, Color(0.05, 0.05, 0.08))
			draw_string(font, Vector2(-w / 2, y + 27), label, HORIZONTAL_ALIGNMENT_CENTER, w, 26, Color.WHITE)
		else:
			draw_string(font, Vector2(-w / 2, y + 27), "속성 없음", HORIZONTAL_ALIGNMENT_CENTER, w, 26, Color(0.7, 0.7, 0.7))
		draw_rect(Rect2(-w / 2, y, w, 34), Color(0.8, 0.8, 0.85), false, 3)
