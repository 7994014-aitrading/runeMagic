class_name Battle
extends Node2D
## 전투: 웨이브 15개(고정 시드), 적 풀, 성 체력, 상태 반응, 피해 출처 통계.
## 웨이브 = 그 웨이브 적이 모두 나오고 모두 죽으면 끝. 끝나면 wave_cleared 신호.

signal finished(won: bool)
signal wave_started(wave: int)
signal wave_cleared(wave: int)

@export var combat: CombatConfig
@export var runner: EnemyData
@export var swarm: EnemyData
@export var tank: EnemyData
@export var boss: EnemyData
@export var boss_traits: BossTraitList
@export var seed: int = 12345
@export var castle_y: float = 1290.0
@export var pool_size: int = 80
@export var invincible: bool = false

var running := false  # 판이 끝나지 않았음
var fighting := false  # 웨이브 진행 중
var wave := 0
var elapsed := 0.0
var castle_hp := 0
var kills := 0
var leaks := 0
var draws := 0
var stats := {"direct": 0.0, "burn": 0.0, "chain": 0.0, "reaction": 0.0, "burst": 0.0}
var reaction_counts := {"증기 폭발": 0, "화상 전파": 0, "빙결": 0}
var result_text := ""
var start_wave := 1  # debug: start from this wave
var test_mode := false  # boss combo test: no wave flow
var summon_cap_hits := 0
var _rng := RandomNumberGenerator.new()

var _pool: Array[Enemy] = []
var _schedule: Array = []  # [{t, data, x, y}]
var _next := 0
var _wave_time := 0.0
var _texts: Array = []  # [{text, pos, t, color}]
var _lines: Array = []  # 연쇄·전파 선 [{a, b, t, color}]
var _rings: Array = []  # 폭발 원 [{pos, r, t, color}]
var _fx: Node2D

func _ready() -> void:
	for i in pool_size:
		var e := Enemy.new()
		e.battle = self
		e.visible = false
		add_child(e)
		_pool.append(e)
	_fx = Node2D.new()
	add_child(_fx)
	_fx.draw.connect(_draw_fx)

func start() -> void:
	for e in _pool:
		e.despawn()
	elapsed = 0.0
	castle_hp = combat.castle_hp
	kills = 0
	leaks = 0
	draws = 0
	for k in stats.keys():
		stats[k] = 0.0
	for k in reaction_counts.keys():
		reaction_counts[k] = 0
	result_text = ""
	_texts.clear()
	_lines.clear()
	_rings.clear()
	wave = start_wave - 1
	_rng.seed = seed
	summon_cap_hits = 0
	running = true
	next_wave()

func next_wave() -> void:
	wave += 1
	_build_wave(wave)
	_next = 0
	_wave_time = 0.0
	fighting = true
	wave_started.emit(wave)

## 디버그: 지금 웨이브를 깬 것으로 처리
func skip_wave() -> void:
	if not fighting:
		return
	for e in _pool:
		e.despawn()
	_next = _schedule.size()

func _build_wave(w: int) -> void:
	_schedule.clear()
	var rng := RandomNumberGenerator.new()
	rng.seed = seed + w * 101
	_wave_rng.seed = seed + w * 7919
	var k := float(w - 1) / maxf(combat.wave_count - 1, 1)
	var budget := combat.budget_base + combat.budget_per_wave * (w - 1)
	var bi := combat.boss_waves.find(w)
	if bi >= 0:
		budget *= combat.boss_wave_budget_ratio
		_schedule.append({"t": combat.boss_spawn_time, "data": boss, "x": 540.0, "y": -100.0, "boss": bi})
	var t := 1.0
	while budget > 0.0:
		var roll := rng.randf()
		if w >= combat.tank_from_wave and roll < 0.25 and budget >= combat.cost_tank:
			_schedule.append({"t": t, "data": tank, "x": rng.randf_range(200, 880), "y": -60.0})
			budget -= combat.cost_tank
		elif roll < 0.6:
			var cx := rng.randf_range(250, 830)
			var n := 5 + w / 3
			for i in n:
				_schedule.append({"t": t, "data": swarm, "x": cx + rng.randf_range(-90, 90), "y": -40.0 - rng.randf_range(0, 160)})
			budget -= n * combat.cost_swarm
		else:
			var n := 2 + w / 4
			for i in n:
				_schedule.append({"t": t + i * 0.45, "data": runner, "x": rng.randf_range(150, 930), "y": -40.0})
			budget -= n * combat.cost_runner
		t += lerpf(combat.gap_start, combat.gap_end, k) + rng.randf_range(-0.5, 0.5)
	_schedule.sort_custom(func(a, b): return a.t < b.t)

func _process(delta: float) -> void:
	_tick_fx(delta)
	if not running or not fighting:
		return
	elapsed += delta
	_wave_time += delta
	while _next < _schedule.size() and _schedule[_next].t <= _wave_time:
		var s: Dictionary = _schedule[_next]
		var e := _free_enemy()
		if e != null:
			_spawn_entry(e, s, rng_for_wave())
		_next += 1
	if not test_mode and _next >= _schedule.size() and active_count() == 0:
		fighting = false
		if wave >= combat.wave_count:
			_end(true)
		else:
			wave_cleared.emit(wave)
	queue_redraw()

func _free_enemy() -> Enemy:
	for e in _pool:
		if not e.active:
			return e
	return null

func active_count() -> int:
	var n := 0
	for e in _pool:
		if e.active:
			n += 1
	return n

func active_enemies() -> Array[Enemy]:
	var out: Array[Enemy] = []
	for e in _pool:
		if e.active:
			out.append(e)
	return out

# ---- 피해 ----

func deal_damage(e: Enemy, amount: float, source: String, element: int = Element.NONE) -> void:
	if not e.active:
		return
	amount = e.modify_damage(amount, element)
	stats[source] += minf(amount, maxf(e.hp, 0.0))  # count only damage that removed hp (no overkill)
	e.hp -= amount
	if e.hp <= 0.0:
		kills += 1
		e.despawn()
		if e.is_boss:
			for o in _pool:
				if o.active and o.owner_boss == e:
					o.despawn()

func enemy_reached(e: Enemy) -> void:
	leaks += 1
	if not invincible:
		castle_hp -= e.data.castle_damage
	e.despawn()
	if e.is_boss and wave >= combat.wave_count and not invincible:
		castle_hp = 0  # final boss got through = defeat
	if castle_hp <= 0:
		castle_hp = 0
		_end(false)

## damage: direct hit (empowered already applied) / base_damage: before empowered, used for chain
func on_projectile_hit(e: Enemy, damage: float, element: int, base_damage: float) -> void:
	var pos := e.position
	deal_damage(e, damage, "direct", element)
	apply_element(e, element)
	if element == Element.LIGHTNING:
		_chain(e, pos, base_damage)

## 완벽 시 속성 폭발 (강화): 그린 자리 주변 적에게 피해 + 속성
func burst(center: Vector2, element: int, radius: float, damage: float) -> void:
	if not fighting:
		return
	_rings.append({"pos": center, "r": radius, "t": 0.3, "color": Element.color_of(element)})
	for o in active_enemies():
		if o.position.distance_to(center) <= radius:
			o.flash(Element.color_of(element))
			deal_damage(o, damage, "burst", element)
			apply_element(o, element)

func _chain(src: Enemy, from: Vector2, damage: float) -> void:
	var hit: Array = [src]
	var cur := from
	for i in combat.chain_count:
		var best: Enemy = null
		var best_d := combat.chain_range * combat.chain_range
		for e in _pool:
			if e.active and not hit.has(e):
				var d := cur.distance_squared_to(e.position)
				if d < best_d:
					best_d = d
					best = e
		if best == null:
			break
		hit.append(best)
		_lines.append({"a": cur, "b": best.position, "t": 0.15, "color": Element.color_of(Element.LIGHTNING)})
		cur = best.position
		best.flash(Element.color_of(Element.LIGHTNING))
		deal_damage(best, damage * combat.chain_damage_ratio, "chain", Element.LIGHTNING)
		apply_element(best, Element.LIGHTNING)

## 속성 적용. 반응 조건이 맞으면 반응, 아니면 상태를 남긴다.
func apply_element(e: Enemy, element: int) -> void:
	if not e.active or element == Element.NONE:
		return
	if e.blocks_element(element):
		return
	if e.reaction_cd <= 0.0:
		var can_freeze := e.freeze_immune_t <= 0.0 and e.freeze_t <= 0.0
		if element == Element.FIRE and e.slow_t > 0.0:
			_steam(e, false)
			return
		if element == Element.FIRE and e.shock_t > 0.0:
			_spread(e)
			return
		if element == Element.ICE and e.burn_t > 0.0:
			_steam(e, true)
			return
		if element == Element.ICE and e.shock_t > 0.0 and can_freeze:
			_freeze(e)
			return
		if element == Element.LIGHTNING and e.burn_t > 0.0:
			_spread(e)
			return
		if element == Element.LIGHTNING and e.slow_t > 0.0 and can_freeze:
			_freeze(e)
			return
	if element == Element.FIRE:
		e.apply_burn(combat)
	elif element == Element.ICE:
		e.slow_t = combat.slow_duration
	elif element == Element.LIGHTNING:
		e.shock_t = combat.shock_duration

func _react(e: Enemy, rname: String, color: Color) -> void:
	e.reaction_cd = combat.reaction_cooldown
	reaction_counts[rname] += 1
	e.on_reaction()
	_texts.append({"text": rname, "pos": e.position + Vector2(0, -60), "t": 0.0, "color": color})

## 증기 폭발: 기본 피해 + 소모된 화상의 남은 피해 전부를 범위에.
func _steam(e: Enemy, had_burn: bool) -> void:
	var extra := e.remaining_burn_damage() if had_burn else combat.burn_dps * combat.burn_duration
	var center := e.position
	e.burn_t = 0.0
	e.slow_t = 0.0
	_react(e, "증기 폭발", Color(0.95, 0.95, 1.0))
	_rings.append({"pos": center, "r": combat.steam_radius, "t": 0.25, "color": Color.WHITE})
	var dmg := combat.steam_base_damage + extra
	for o in active_enemies():
		if o.position.distance_to(center) <= combat.steam_radius:
			deal_damage(o, dmg, "reaction")

## 화상 전파: 근처 적에게 화상 (원래 수치 그대로, 추가 반응은 일으키지 않음).
func _spread(e: Enemy) -> void:
	var center := e.position
	e.burn_t = 0.0
	e.shock_t = 0.0
	_react(e, "화상 전파", Element.color_of(Element.FIRE))
	for o in active_enemies():
		if o != e and o.position.distance_to(center) <= combat.spread_radius:
			_lines.append({"a": center, "b": o.position, "t": 0.2, "color": Element.color_of(Element.FIRE)})
			o.apply_burn(combat)

func _freeze(e: Enemy) -> void:
	e.slow_t = 0.0
	e.shock_t = 0.0
	e.freeze_t = combat.freeze_duration
	_react(e, "빙결", Element.color_of(Element.ICE))

func _end(won: bool) -> void:
	if not running:
		return
	running = false
	fighting = false
	for e in _pool:
		e.despawn()
	result_text = "승리" if won else "패배"
	finished.emit(won)


# ---- boss ----

var _wave_rng := RandomNumberGenerator.new()

func rng_for_wave() -> RandomNumberGenerator:
	return _wave_rng

func _spawn_entry(e: Enemy, s: Dictionary, rng: RandomNumberGenerator) -> void:
	if s.has("boss"):
		var bi: int = s.boss
		var traits := pick_traits(combat.boss_trait_counts[bi], rng)
		e.spawn(s.data, Vector2(s.x, s.y), combat.boss_hp_multipliers[bi], traits, null, true)
	else:
		e.spawn(s.data, Vector2(s.x, s.y))

## count traits, at most one per category
func pick_traits(count: int, rng: RandomNumberGenerator) -> Array:
	var out: Array = []
	var used := {}
	var pool: Array = boss_traits.items.duplicate()
	while out.size() < count and not pool.is_empty():
		var t: BossTrait = pool.pop_at(rng.randi_range(0, pool.size() - 1))
		if used.has(t.category):
			continue
		used[t.category] = true
		out.append(t)
	return out

func random_element(exclude: int) -> int:
	var opts := [Element.FIRE, Element.ICE, Element.LIGHTNING]
	opts.erase(exclude)
	return opts[_rng.randi_range(0, opts.size() - 1)]

func summon_minions(owner: Enemy, n: int, cap: int) -> void:
	var alive := 0
	for o in _pool:
		if o.active and o.owner_boss == owner:
			alive += 1
	var make := mini(n, cap - alive)
	if make < n:
		summon_cap_hits += 1
	for i in make:
		var e := _free_enemy()
		if e == null:
			return
		var off := Vector2(_rng.randf_range(-140, 140), _rng.randf_range(20, 90))
		e.spawn(swarm, owner.position + off, 1.0, [], owner)

func float_text(e: Enemy, text: String, color: Color) -> void:
	_texts.append({"text": text, "pos": e.position + Vector2(0, -110), "t": 0.0, "color": color})

## test: clear field and spawn one boss with given traits
func spawn_test_boss(traits: Array, shield_element: int, hp_mult: float) -> Enemy:
	for o in _pool:
		o.despawn()
	var e := _free_enemy()
	e.spawn(boss, Vector2(540, -60), hp_mult, traits, null, true)
	if shield_element != Element.NONE:
		e.shield_element = shield_element
	return e

# ---- 그리기 ----

func _tick_fx(delta: float) -> void:
	for x in _texts:
		x.t += delta
	for x in _lines:
		x.t -= delta
	for x in _rings:
		x.t -= delta
	while _texts.size() > 0 and _texts[0].t > 0.9:
		_texts.pop_front()
	_lines = _lines.filter(func(l): return l.t > 0.0)
	_rings = _rings.filter(func(r): return r.t > 0.0)
	_fx.queue_redraw()

func _draw() -> void:
	draw_line(Vector2(0, castle_y), Vector2(1080, castle_y), Color(0.85, 0.75, 0.5), 6)
	var font := ThemeDB.fallback_font
	draw_string(font, Vector2(20, castle_y + 44), "성 %d / %d" % [castle_hp, combat.castle_hp], HORIZONTAL_ALIGNMENT_LEFT, 300, 34, Color(0.95, 0.85, 0.6))
	draw_string(font, Vector2(760, castle_y + 44), "웨이브 %d / %d" % [wave, combat.wave_count], HORIZONTAL_ALIGNMENT_RIGHT, 300, 34, Color(0.85, 0.85, 0.9))

func _draw_fx() -> void:
	var font := ThemeDB.fallback_font
	for l in _lines:
		_fx.draw_line(l.a, l.b, l.color, 6)
	for r in _rings:
		var rc: Color = r.color
		rc.a = clampf(r.t * 4.0, 0, 1)
		_fx.draw_arc(r.pos, r.r, 0, TAU, 40, rc, 8)
	for t in _texts:
		var c: Color = t.color
		c.a = 1.0 - t.t / 0.9
		var p: Vector2 = t.pos + Vector2(-150, -t.t * 80.0)
		_fx.draw_string_outline(font, p, t.text, HORIZONTAL_ALIGNMENT_CENTER, 300, 40, 8, Color(0, 0, 0, c.a))
		_fx.draw_string(font, p, t.text, HORIZONTAL_ALIGNMENT_CENTER, 300, 40, c)
