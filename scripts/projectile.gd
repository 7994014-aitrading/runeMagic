class_name Projectile
extends Node2D
## 풀링용 투사체. Wizard가 미리 만들어 두고 launch()로 재사용한다.

var active := false
var element := Element.NONE
var empowered := false
var damage := 0.0
var base_damage := 0.0  # before empowered multiplier (chain uses this)
var speed := 1600.0
var target: Node2D

func launch(from: Vector2, tgt: Node2D, elem: int, dmg: float, spd: float, emp: bool, base_dmg: float) -> void:
	base_damage = base_dmg
	global_position = from
	target = tgt
	element = elem
	damage = dmg
	speed = spd
	empowered = emp
	active = true
	visible = true
	queue_redraw()

func _process(delta: float) -> void:
	if not active:
		return
	if not is_instance_valid(target) or not target.is_targetable():
		_release()
		return
	var to := target.global_position - global_position
	var step := speed * delta
	if to.length() <= step + 30.0:
		target.take_hit(damage, element, empowered, base_damage)
		_release()
	else:
		global_position += to.normalized() * step

func _release() -> void:
	active = false
	visible = false
	target = null

func _draw() -> void:
	var r := 30.0 if empowered else 18.0
	var c := Element.color_of(element)
	draw_circle(Vector2.ZERO, r, c)
	draw_circle(Vector2.ZERO, r * 0.45, Color(1, 1, 1, 0.9))
	if empowered:
		draw_arc(Vector2.ZERO, r + 8.0, 0.0, TAU, 24, c, 4.0, true)
