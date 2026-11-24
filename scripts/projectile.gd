class_name Projectile
extends Node2D
## 풀링용 투사체. Wizard가 미리 만들어 두고 launch()로 재사용한다.

var active := false
var element := Element.NONE
var empowered := false
var damage := 0.0
var base_damage := 0.0  # before empowered multiplier (chain uses this)
var bonus := 0.0  # 역화 보상: 맞으면 탄 속성으로 추가 피해 (강화탄 배율 미적용). 발사마다 다시 정한다
var wizard_ref: Wizard  # 계측용
var _target_gen := 0  # 발사 때 대상 적의 세대 (Enemy.gen)
var speed := 1600.0
var target: Node2D
var _t := 0.0
var _fx := ""  # Art 이펙트 이름 (없으면 도형)

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

func launch(from: Vector2, tgt: Node2D, elem: int, dmg: float, spd: float, emp: bool, base_dmg: float, bon := 0.0) -> void:
	base_damage = base_dmg
	bonus = bon
	global_position = from
	target = tgt
	_target_gen = (tgt as Enemy).gen if tgt is Enemy else 0
	element = elem
	damage = dmg
	speed = spd
	empowered = emp
	_t = 0.0
	_fx = Art.projectile_fx(elem)
	if Art.fx_sheet(_fx) == null:
		_fx = ""
	if is_instance_valid(tgt):
		rotation = (tgt.global_position - from).angle()
	active = true
	visible = true
	queue_redraw()

func _process(delta: float) -> void:
	if not active:
		return
	if not is_instance_valid(target) or not target.is_targetable() or (target is Enemy and (target as Enemy).gen != _target_gen):
		_count_lost()
		_release()
		return
	var to := target.global_position - global_position
	var step := speed * delta
	if to.length() <= step + 30.0:
		if target is Enemy:
			target.take_hit(damage, element, empowered, base_damage, bonus)
		else:
			target.take_hit(damage, element, empowered, base_damage)
		_release()
	else:
		global_position += to.normalized() * step
		rotation = to.angle()  # 시트는 오른쪽을 보고 있다
		_t += delta
		queue_redraw()

## 비행 중 대상이 사라짐: 강화탄·역화 보상은 환급하지 않고 소실로 센다
func _count_lost() -> void:
	if wizard_ref == null:
		return
	if empowered:
		wizard_ref._m("emp_lost")
	if bonus > 0.0:
		wizard_ref._m("bf_lost")

## 새 판 시작: 비행 중 탄을 조용히 거둔다 (계측 없음)
func discard() -> void:
	_release()

func _release() -> void:
	active = false
	visible = false
	target = null

func _draw() -> void:
	if _fx != "":
		var size := 150.0 if empowered else 100.0
		if empowered:
			draw_circle(Vector2.ZERO, 34.0, Color(Element.color_of(element), 0.35))
		Art.draw_fx_frame(self, _fx, int(_t * Art.FX_FPS), Vector2.ZERO, size)
		return
	var r := 30.0 if empowered else 18.0
	var c := Element.color_of(element)
	draw_circle(Vector2.ZERO, r, c)
	draw_circle(Vector2.ZERO, r * 0.45, Color(1, 1, 1, 0.9))
	if empowered:
		draw_arc(Vector2.ZERO, r + 8.0, 0.0, TAU, 24, c, 4.0, true)
