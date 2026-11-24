extends SceneTree
## 불 변형 고정 장면 검사 (headless). 인식 흔들림만 빼고 실제 시전 경로(main.cast_rune)와 발사·적중을 그대로 쓴다.
## 적은 움직이지 않고 체력이 큰 허수아비(탱커 복제). 보스·강화·웨이브 없음.
## 사용: godot --headless --path . --fixed-fps 30 -s tools/test_variants.gd   (끝에 [test] done fails=N)

const DT := 1.0 / 30.0
var main
var battle
var wizard
var fails := 0

func _init() -> void:
	await process_frame
	get_root().get_node("GameState").current_stage = 0  # 시험 판: 룬 3개, 스테이지 수치 없음
	change_scene_to_file("res://scenes/main.tscn")
	await process_frame
	await process_frame
	main = current_scene
	main.allow_try_variant = false  # 사용자 설정의 시험 토글이 검사에 섞이지 않게
	battle = main.battle
	wizard = main.wizard
	_test_formula()
	await _test_snapshot()
	await _test_two_slot_refresh()
	await _test_push_out()
	await _test_perfect_and_backfire()
	await _test_overwrite()
	await _test_target_lost()
	await _test_new_run_clears_shots()
	await _test_blaze()
	await _test_rapid()
	await _compare_tactics()
	print("[test] done fails=%d" % fails)
	quit(1 if fails > 0 else 0)

# ---- 도구 ----

func check(name: String, cond: bool, info := "") -> void:
	print("[test] %s %s %s" % ["PASS" if cond else "FAIL", name, info])
	if not cond:
		fails += 1

func near(a: float, b: float, tol := 0.5) -> bool:
	return absf(a - b) <= tol

func mv(key: String) -> float:
	return float(battle.m.get(key, 0))

func setup(fv: String, slots: int) -> void:
	main._fire_variant_id = fv
	main._new_run()
	battle.test_mode = true
	battle.invincible = true
	battle._schedule.clear()
	battle._next = 0
	for e in battle._pool:
		e.despawn()
	wizard.set_slot_count(slots)
	wizard.clear_slots()
	battle.m.clear()
	for k in battle.stats.keys():
		battle.stats[k] = 0.0
	battle.burn_charge = 0.0

func dummy(pos: Vector2, hp := 1000000.0) :
	var d: EnemyData = battle.tank.duplicate()
	d.speed = 0.0
	d.hp = hp
	var e = battle._free_enemy()
	e.spawn(d, pos, 1.0)
	return e

func wait(sec: float) -> void:
	for i in int(round(sec / DT)):
		await process_frame

func wait_until(cond: Callable, max_sec := 3.0) -> bool:
	for i in int(max_sec / DT):
		if cond.call():
			return true
		await process_frame
	return cond.call()

func cast(e: int, tier := "good") -> String:
	return main.cast_rune(e, tier, Vector2(540, 700))

# ---- 1. 식 (순수 계산) ----

func _test_formula() -> void:
	var mn := RuneVariant.load_id("backfire")
	var rem := RuneVariant.load_id("backfire_rem")
	var ch := RuneVariant.load_id("backfire_charge")
	check("식 min 경과2 잔여10", near(mn.backfire_reward(12, 10, 0, 1), 10 * 2))
	check("식 rem 경과2 잔여10", near(rem.backfire_reward(12, 10, 0, 1), 10 * 10))
	check("식 min 경과6 잔여6", near(mn.backfire_reward(12, 6, 0, 1), 60))
	check("식 rem 경과6 잔여6", near(rem.backfire_reward(12, 6, 0, 1), 60))
	check("식 min 갱신 직후 0", near(mn.backfire_reward(12, 12, 0, 1), 0))
	check("식 rem 갱신 직후 최대", near(rem.backfire_reward(12, 12, 0, 1), 120))
	check("식 charge 50", near(ch.backfire_reward(12, 6, 50, 1), 55))
	var gated: RuneVariant = mn.duplicate()
	gated.backfire_require_hit = true
	check("식 명중 조건 0회면 0", near(gated.backfire_reward(12, 6, 0, 0), 0))

# ---- 2. 교체 전 잔여 시간 ----

func _test_snapshot() -> void:
	setup("backfire_rem", 1)
	cast(Element.FIRE)
	wizard.slots[0].time_left = 2.5
	var kind: String = cast(Element.ICE, "good")  # 새 얼음 10초
	check("스냅샷 교체", kind == "replace" and wizard.last_replaced == Element.FIRE)
	check("스냅샷 잔여 2.5초 기준", near(wizard.last_replaced_left, 2.5, 0.01) and near(wizard.bonus_pending, 25, 0.01),
		"left=%.2f bonus=%.1f" % [wizard.last_replaced_left, wizard.bonus_pending])
	setup("backfire", 1)
	cast(Element.FIRE)  # 10초
	wizard.slots[0].time_left = 8.0  # 경과 2초
	cast(Element.ICE)
	check("스냅샷 min 경과2 잔여8 = 20", near(wizard.bonus_pending, 20, 0.01), "bonus=%.1f" % wizard.bonus_pending)

# ---- 3. 2칸 불·얼음 번갈아 갱신: 자동 발동 없음 ----

func _test_two_slot_refresh() -> void:
	setup("backfire", 2)
	dummy(Vector2(540, 700))
	var kinds := []
	kinds.append(cast(Element.FIRE))
	await wait(0.5)
	kinds.append(cast(Element.ICE))
	for i in 6:
		await wait(1.0)
		kinds.append(cast(Element.FIRE))
		await wait(1.0)
		kinds.append(cast(Element.ICE))
	check("2칸 번갈아 갱신: 역화 0", mv("bf_reserved") == 0 and kinds.count("replace") == 0, "kinds=%s" % [kinds])

# ---- 4. 2칸에서 제3속성으로 불 밀어내기: 정확히 한 번 ----

func _test_push_out() -> void:
	setup("backfire", 2)
	dummy(Vector2(540, 700))
	cast(Element.FIRE)
	await wait(3.0)
	cast(Element.ICE)  # 불 7초 남음 < 얼음 10초
	var fire_left: float = wizard.remaining_of(Element.FIRE)
	var kind: String = cast(Element.LIGHTNING)
	var expect := 10.0 * minf(10.0 - fire_left, fire_left)
	check("밀어내기: 불 칸 교체", kind == "replace" and wizard.last_replaced == Element.FIRE)
	check("밀어내기: 예약 1회, 보상 = 10 x min(경과, 잔여)", mv("bf_reserved") == 1 and near(wizard.bonus_pending, expect, 0.01),
		"bonus=%.1f expect=%.1f" % [wizard.bonus_pending, expect])
	await wait_until(func(): return mv("bf_hit") >= 1)
	await wait(2.0)
	check("밀어내기: 발사·적중 정확히 1회", mv("bf_fired") == 1 and mv("bf_hit") == 1 and near(battle.stats.variant, expect),
		"fired=%d hit=%d variant=%.1f" % [mv("bf_fired"), mv("bf_hit"), battle.stats.variant])

# ---- 5. 완벽 교체(강화탄)와 역화가 같은 탄에 독립 적용 ----

func _test_perfect_and_backfire() -> void:
	setup("backfire", 1)
	dummy(Vector2(540, 700))
	cast(Element.FIRE)
	await wait(4.0)
	var left: float = wizard.remaining_of(Element.FIRE)
	var expect := 10.0 * minf(10.0 - left, left)
	cast(Element.ICE, "perfect")
	check("완벽 교체: 강화탄 예약 유지", wizard.empower_element == Element.ICE)
	check("완벽 교체: 역화 예약", near(wizard.bonus_pending, expect, 0.01), "bonus=%.1f" % wizard.bonus_pending)
	await wait_until(func(): return mv("bf_hit") >= 1)
	check("같은 첫 탄에 둘 다", mv("emp_fired") == 1 and mv("bf_fired") == 1 and mv("emp_hit") == 1 and mv("bf_hit") == 1)
	check("역화 피해는 2배 안 됨", near(battle.stats.variant, expect), "variant=%.1f expect=%.1f" % [battle.stats.variant, expect])

# ---- 6. 발사 대기 중 다시 역화: 덮어쓰기, 중복 소비 없음 ----

func _test_overwrite() -> void:
	setup("backfire_rem", 1)  # 적 없음 → 발사 없음
	cast(Element.FIRE)
	await wait(1.0)
	cast(Element.ICE)
	var r1: float = wizard.bonus_pending
	cast(Element.FIRE)
	await wait(0.5)
	cast(Element.ICE)
	var r2: float = wizard.bonus_pending
	check("덮어쓰기: 예약 2·덮어쓰기 1", mv("bf_reserved") == 2 and mv("bf_overwritten") == 1, "r1=%.1f r2=%.1f" % [r1, r2])
	dummy(Vector2(540, 700))
	await wait_until(func(): return mv("bf_hit") >= 1)
	await wait(2.0)
	check("덮어쓰기: 발사 1회, 피해 = 마지막 예약", mv("bf_fired") == 1 and mv("bf_hit") == 1 and near(battle.stats.variant, r2),
		"variant=%.1f" % battle.stats.variant)

# ---- 7. 비행 중 대상 소실, 투사체 재사용 ----

func _test_target_lost() -> void:
	setup("backfire_rem", 1)
	var a = dummy(Vector2(540, 150))  # 멀리: 비행 시간 확보
	cast(Element.FIRE)
	await wait(1.0)
	cast(Element.ICE)
	await wait_until(func(): return mv("bf_fired") >= 1)
	var b = dummy(Vector2(540, 700))  # 먼저 띄워야 풀에서 a와 다른 적이 나온다
	a.despawn()
	await wait(2.5)
	check("소실: 환급 없음", mv("bf_lost") == 1 and mv("bf_hit") == 0 and wizard.bonus_pending == 0.0)
	check("재사용: 다음 탄들에 보상 안 남음", battle.stats.variant == 0.0 and battle.stats.direct > 0.0 and b.hp < b.max_hp,
		"variant=%.1f direct=%.1f" % [battle.stats.variant, battle.stats.direct])
	# 같은 노드 재사용: 죽은 a 자리에 풀이 같은 노드로 새 적을 내도 옛 탄은 맞지 않는다
	setup("backfire_rem", 1)
	var c = dummy(Vector2(540, 150))
	cast(Element.FIRE)
	await wait(1.0)
	cast(Element.ICE)
	await wait_until(func(): return mv("bf_fired") >= 1)
	c.despawn()
	var d = dummy(Vector2(540, 700))
	check("같은 노드 재사용 상황 재현", d == c)
	await wait(2.5)
	check("같은 노드 재사용: 옛 탄은 소실", mv("bf_lost") == 1 and mv("bf_hit") == 0 and battle.stats.variant == 0.0,
		"lost=%d hit=%d variant=%.1f" % [mv("bf_lost"), mv("bf_hit"), battle.stats.variant])

# ---- 7b. 새 판 시작 때 이전 탄이 남지 않음 ----

func _test_new_run_clears_shots() -> void:
	setup("", 1)
	var e = dummy(Vector2(540, 150))
	cast(Element.ICE)
	await wait_until(func(): return wizard._pool.any(func(p): return p.active))
	setup("", 1)  # 탄이 날아가는 중에 새 판
	var flying: int = wizard._pool.filter(func(p): return p.active).size()
	var e2 = dummy(Vector2(540, 700))
	await wait(1.5)
	check("새 판: 비행 중 탄 정리", flying == 0)
	check("새 판: 옛 얼음 탄이 새 적에 감속 안 남김", e2.slow_t <= 0.0, "slow=%.2f" % e2.slow_t)

# ---- 8. 폭염: 감속된 원래 대상 + 주변 (반응 → 주변 화상, 원래 대상 제외) ----

func _test_blaze() -> void:
	setup("blaze", 1)
	var p = dummy(Vector2(540, 700))
	var n1 = dummy(Vector2(700, 700))  # 신규
	var n2 = dummy(Vector2(380, 700))  # 이미 화상
	var far = dummy(Vector2(540, 300))  # 반경 밖
	n2.apply_burn(battle.combat)
	p.slow_t = 5.0
	cast(Element.FIRE, "perfect")
	await wait_until(func(): return mv("emp_hit_fire") >= 1)
	check("폭염: 증기 폭발 1회 (정상 반응)", battle.reaction_counts["증기 폭발"] == 1)
	check("폭염: 원래 대상 재부착 없음", p.burn_t <= 0.0, "p.burn_t=%.2f" % p.burn_t)
	check("폭염: 신규 1·갱신 1·시도 2", mv("blaze_new") == 1 and mv("blaze_refresh") == 1 and mv("blaze_tries") == 2,
		"new=%d refresh=%d tries=%d" % [mv("blaze_new"), mv("blaze_refresh"), mv("blaze_tries")])
	check("폭염: 유효 발동 1", mv("blaze_procs") == 1 and mv("blaze_procs_hit") == 1)
	check("폭염: 반경 밖 없음, 표시", far.burn_t <= 0.0 and n1.burn_from_blaze and n2.burn_from_blaze)
	await wait(2.0)
	check("폭염: 후속 화상 피해 집계", mv("blaze_burn_dmg") > 0.0, "blaze_burn_dmg=%.1f" % mv("blaze_burn_dmg"))

# ---- 9. 빠른 입력 (0.3초 간격): 예약·발사·적중 보존 ----

func _test_rapid() -> void:
	setup("backfire_rem", 1)
	dummy(Vector2(540, 700))
	for i in 20:
		cast(Element.FIRE)
		await wait(0.3)
		cast(Element.ICE)
		await wait(0.3)
	await wait(2.0)
	var pending := 1 if wizard.bonus_pending > 0.0 else 0
	check("빠른 입력: 예약 = 발사 + 덮어쓰기 + 대기", mv("bf_reserved") == mv("bf_fired") + mv("bf_overwritten") + pending,
		"reserved=%d fired=%d over=%d pending=%d" % [mv("bf_reserved"), mv("bf_fired"), mv("bf_overwritten"), pending])
	check("빠른 입력: 발사 = 적중 + 소실", mv("bf_fired") == mv("bf_hit") + mv("bf_lost"))
	check("빠른 입력: 피해 집계 일치", near(mv("bf_damage"), battle.stats.variant))

# ---- 10. 전술 비교 (보고용, 통과 기준 없음): 1칸, 허수아비 5, 판정 "좋음"(10초), 40초 ----
## hold 불 유지 / expiry 만료 직전 교체 / mid 불 5초 → 얼음 0.8초 반복 / spam 0.8초마다 불↔얼음

func _compare_tactics() -> void:
	for fv in ["", "backfire", "backfire_rem", "backfire_charge"]:
		for tactic in ["hold", "expiry", "mid", "spam"]:
			setup(fv, 1)
			for pos in [Vector2(540, 700), Vector2(640, 680), Vector2(440, 680), Vector2(590, 600), Vector2(490, 600)]:
				dummy(pos)
			var casts := await _run_tactic(tactic, 40.0)
			var total := _total()
			if fv == "" and tactic == "hold":
				_hold_total = total
				check("격리: 불만 유지하면 반응 0", battle.stats.reaction == 0.0, "reaction=%d" % int(battle.stats.reaction))
			print("[tactic] fv=%s tactic=%s total=%d dps=%.1f variant=%d bf=%d burn=%d reaction=%d casts=%d per_cast=%.1f" % [
				fv if fv != "" else "base", tactic, int(total), total / 40.0, int(battle.stats.variant), int(mv("bf_reserved")),
				int(battle.stats.burn), int(battle.stats.reaction), casts, battle.stats.variant / maxf(casts, 1)])

	# 순서 무관: 다른 장면을 다 돌린 뒤 같은 장면을 다시 돌려도 결과가 같다
	setup("", 1)
	for pos in [Vector2(540, 700), Vector2(640, 680), Vector2(440, 680), Vector2(590, 600), Vector2(490, 600)]:
		dummy(pos)
	await _run_tactic("hold", 40.0)
	check("격리: 실행 순서를 바꿔도 같은 결과", near(_total(), _hold_total, 0.01), "first=%.1f again=%.1f" % [_hold_total, _total()])

var _hold_total := 0.0

func _total() -> float:
	var total := 0.0
	for k in battle.stats.keys():
		total += battle.stats[k]
	return total

func _run_tactic(tactic: String, dur: float) -> int:
	var cur := Element.FIRE
	cast(cur)
	var casts := 1
	var since := 0.0
	var t := 0.0
	while t < dur:
		await process_frame
		t += DT
		since += DT
		var swap := false
		match tactic:
			"hold":
				if wizard.remaining_of(Element.FIRE) < 1.0:
					cast(Element.FIRE)
					casts += 1
			"expiry":
				swap = wizard.remaining_of(cur) < 1.0
			"mid":
				swap = since >= (5.0 if cur == Element.FIRE else 0.8)
			"spam":
				swap = since >= 0.8
		if swap:
			cur = Element.ICE if cur == Element.FIRE else Element.FIRE
			cast(cur)
			casts += 1
			since = 0.0
	return casts
