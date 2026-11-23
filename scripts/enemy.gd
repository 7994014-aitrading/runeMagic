class_name Enemy
extends Node2D
## 풀링되는 적. 상태(화상·감속·감전·빙결)와 보스 특성 상태를 들고 있다.
## 피해·반응 판단은 Battle이 하고, 특성은 정해진 순서의 훅(modify_damage → blocks_element → on_reaction)과
## 매 프레임 타이머(재생·소환·돌진)로 동작한다.

var battle: Battle
var data: EnemyData
var active := false
var hp := 0.0
var max_hp := 0.0
var is_boss := false
var owner_boss: Enemy = null  # 소환한 보스 (졸개만)

var burn_t := 0.0
var burn_dps := 0.0
var _burn_tick := 0.0
var slow_t := 0.0
var shock_t := 0.0
var freeze_t := 0.0
var freeze_immune_t := 0.0
var reaction_cd := 0.0
var _flash := 0.0
var _flash_color := Color.WHITE

# 보스 특성
var traits: Array = []  # BossTrait
var _shield: BossTrait
var _regen: BossTrait
var _summon: BossTrait
var _charge: BossTrait
var shield_element := Element.NONE
var shield_hits := 0
var shield_broken_t := 0.0
var _summon_t := 0.0
var _charge_t := 0.0
var charge_phase := 0  # 0 대기, 1 예고, 2 돌진
var _charge_phase_t := 0.0

func spawn(d: EnemyData, pos: Vector2, hp_mult := 1.0, trait_list: Array = [], owner: Enemy = null, boss := false) -> void:
	data = d
	max_hp = d.hp * hp_mult
	hp = max_hp
	position = pos
	is_boss = boss
	owner_boss = owner
	burn_t = 0.0
	slow_t = 0.0
	shock_t = 0.0
	freeze_t = 0.0
	freeze_immune_t = 0.0
	reaction_cd = 0.0
	_flash = 0.0
	traits = trait_list
	_shield = null
	_regen = null
	_summon = null
	_charge = null
	for t in traits:
		match t.id:
			"shield": _shield = t
			"regen": _regen = t
			"summon": _summon = t
			"charge": _charge = t
	shield_element = battle.random_element(Element.NONE) if _shield != null else Element.NONE
	shield_hits = 0
	shield_broken_t = 0.0
	_summon_t = _summon.interval if _summon != null else 0.0
	_charge_t = _charge.interval if _charge != null else 0.0
	charge_phase = 0
	active = true
	visible = true
	add_to_group("targets")

func despawn() -> void:
	active = false
	visible = false
	if is_in_group("targets"):
		remove_from_group("targets")

func is_targetable() -> bool:
	return active

## 투사체가 부른다.
func take_hit(damage: float, element: int, _empowered: bool, base_damage: float) -> void:
	if active:
		flash(Element.color_of(element))
		battle.on_projectile_hit(self, damage, element, base_damage)

func flash(c: Color) -> void:
	_flash = 0.12
	_flash_color = c

# ---- 특성 훅 (순서: 피해 배율 → 피해 → 상태 막기 → 반응) ----

func shield_active() -> bool:
	return _shield != null and shield_broken_t <= 0.0

## 1. 피격: 피해 배율. element NONE(반응 피해)은 "다른 속성"으로 친다.
func modify_damage(amount: float, element: int) -> float:
	if _shield == null:
		return amount
	if shield_broken_t > 0.0:
		return amount * _shield.multiplier
	if element == shield_element:
		return 0.0
	return amount * _shield.amount

## 3. 상태 부착: 방패와 같은 속성은 상태·반응 모두 막음
func blocks_element(element: int) -> bool:
	return shield_active() and element == shield_element

## 4. 반응: 방패가 반응 횟수를 센다
func on_reaction() -> void:
	if not shield_active():
		return
	shield_hits += 1
	if shield_hits >= _shield.count:
		shield_broken_t = _shield.duration
		battle.float_text(self, "방패 파괴", Color(1.0, 0.85, 0.3))

func apply_burn(cfg: CombatConfig) -> void:
	var fresh := burn_t <= 0.0
	burn_t = cfg.burn_duration
	burn_dps = cfg.burn_dps
	if fresh:
		_burn_tick = cfg.burn_tick
		battle.deal_damage(self, burn_dps * cfg.burn_tick, "burn", Element.FIRE)  # 맞는 순간 첫 피해

func remaining_burn_damage() -> float:
	return burn_dps * maxf(burn_t, 0.0)

func _process(delta: float) -> void:
	if not active or not battle.running:
		return
	var cfg := battle.combat
	reaction_cd -= delta
	slow_t -= delta
	shock_t -= delta
	_flash -= delta
	if freeze_t > 0.0:
		freeze_t -= delta
		if freeze_t <= 0.0:
			freeze_immune_t = cfg.freeze_immunity
	else:
		freeze_immune_t -= delta
	if burn_t > 0.0:
		burn_t -= delta
		_burn_tick -= delta
		if _burn_tick <= 0.0:
			_burn_tick += cfg.burn_tick
			battle.deal_damage(self, burn_dps * cfg.burn_tick, "burn", Element.FIRE)
			if not active:
				return
	_tick_traits(delta)
	if not active:
		return
	var spd := data.speed
	if charge_phase == 2:
		spd *= _charge.multiplier
	if freeze_t > 0.0:
		spd = 0.0
	elif slow_t > 0.0:
		spd *= cfg.slow_factor
	spd = minf(spd, cfg.max_enemy_speed)
	position.y += spd * delta
	if position.y >= battle.castle_y:
		battle.enemy_reached(self)
		return
	queue_redraw()

func _tick_traits(delta: float) -> void:
	if _shield != null and shield_broken_t > 0.0:
		shield_broken_t -= delta
		if shield_broken_t <= 0.0:
			shield_element = battle.random_element(shield_element)
			shield_hits = 0
	if _regen != null and burn_t <= 0.0 and freeze_t <= 0.0:
		hp = minf(max_hp, hp + max_hp * _regen.amount * delta)
	if _summon != null:
		_summon_t -= delta
		if _summon_t <= 0.0:
			_summon_t = _summon.interval
			battle.summon_minions(self, _summon.count, _summon.max_count)
	if _charge != null:
		match charge_phase:
			0:
				_charge_t -= delta
				if _charge_t <= 0.0:
					charge_phase = 1
					_charge_phase_t = _charge.warn_time
			1:
				_charge_phase_t -= delta
				if _charge_phase_t <= 0.0:
					charge_phase = 2
					_charge_phase_t = _charge.duration
			2:
				_charge_phase_t -= delta
				if _charge_phase_t <= 0.0:
					charge_phase = 0
					_charge_t = _charge.interval

# ---- 그리기 ----

func _draw() -> void:
	if not active:
		return
	var r := data.radius
	var body := data.color
	if _flash > 0.0:
		body = body.lerp(_flash_color, 0.7)
	var font := ThemeDB.fallback_font
	# 돌진 예고·돌진
	if charge_phase == 1:
		var a := 0.4 + 0.4 * sin(_charge_phase_t * 20.0)
		draw_circle(Vector2.ZERO, r + 30, Color(1, 0.2, 0.2, a))
	elif charge_phase == 2:
		draw_circle(Vector2.ZERO, r + 22, Color(1, 0.3, 0.2, 0.5))
	draw_circle(Vector2.ZERO, r, body)
	# 방패
	if _shield != null:
		if shield_active():
			draw_arc(Vector2.ZERO, r + 12, 0, TAU, 48, Element.color_of(shield_element), 12, true)
			var left := _shield.count - shield_hits
			draw_string_outline(font, Vector2(-r, 14), "방패 %d" % left, HORIZONTAL_ALIGNMENT_CENTER, r * 2, 30, 6, Color(0, 0, 0))
			draw_string(font, Vector2(-r, 14), "방패 %d" % left, HORIZONTAL_ALIGNMENT_CENTER, r * 2, 30, Element.color_of(shield_element))
		else:
			draw_arc(Vector2.ZERO, r + 12, 0, TAU, 48, Color(1.0, 0.85, 0.3), 6, true)
			draw_string_outline(font, Vector2(-r, 14), "약점", HORIZONTAL_ALIGNMENT_CENTER, r * 2, 32, 6, Color(0, 0, 0))
			draw_string(font, Vector2(-r, 14), "약점", HORIZONTAL_ALIGNMENT_CENTER, r * 2, 32, Color(1.0, 0.85, 0.3))
	if freeze_t > 0.0:
		draw_rect(Rect2(-r - 6, -r - 6, r * 2 + 12, r * 2 + 12), Color(0.6, 0.9, 1.0, 0.55))
	elif freeze_immune_t > 0.0:
		draw_arc(Vector2.ZERO, r + 6, 0, TAU, 24, Color(0.6, 0.6, 0.6), 4)
	# 체력 바 (보스는 항상, 나머지는 닳았을 때)
	if is_boss or hp < max_hp:
		var w := maxf(r * 2, 40.0)
		var h := 14.0 if is_boss else 8.0
		draw_rect(Rect2(-w / 2, -r - 22, w, h), Color(0.15, 0.15, 0.15))
		draw_rect(Rect2(-w / 2, -r - 22, w * clampf(hp / max_hp, 0, 1), h), Color(0.9, 0.25, 0.25))
	# 특성 아이콘 (보스)
	for i in traits.size():
		var t: BossTrait = traits[i]
		var x := (i - (traits.size() - 1) / 2.0) * 48.0
		draw_rect(Rect2(x - 20, -r - 70, 40, 40), Color(0.1, 0.1, 0.14))
		draw_rect(Rect2(x - 20, -r - 70, 40, 40), Color(0.85, 0.75, 0.5), false, 3)
		draw_string(font, Vector2(x - 20, -r - 40), t.icon_text, HORIZONTAL_ALIGNMENT_CENTER, 40, 28, Color(0.95, 0.9, 0.8))
	# 상태 아이콘
	var icons := []
	if burn_t > 0.0:
		icons.append(["화", Element.color_of(Element.FIRE)])
	if slow_t > 0.0:
		icons.append(["감", Element.color_of(Element.ICE)])
	if shock_t > 0.0:
		icons.append(["전", Element.color_of(Element.LIGHTNING)])
	for i in icons.size():
		var x := (i - (icons.size() - 1) / 2.0) * 30.0
		var c: Color = icons[i][1]
		draw_circle(Vector2(x, r + 18), 13, c)
		draw_string(font, Vector2(x - 13, r + 25), icons[i][0], HORIZONTAL_ALIGNMENT_CENTER, 26, 18, Color(0.08, 0.08, 0.1))
