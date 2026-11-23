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

func _ready() -> void:
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
	p.launch(global_position + Vector2(0, -110), tgt, e, dmg, config.projectile_speed, emp, config.base_damage)

func _draw() -> void:
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
	# 칸 게이지
	var font := ThemeDB.fallback_font
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
