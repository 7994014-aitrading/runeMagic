extends Node2D
## 메인: 획 입력 → 인식 → 마법사 속성 칸 적용, 판정 표시, 로그, 룬 안내.
## Battle 노드가 있으면 웨이브 전투 + 강화 3택1 + 디버그 패널, Dummy 노드가 있으면 허수아비 시험.
## 실행 인자: `-- --autoplay` 정해둔 획 자동 재생, `-- --bot=fire|duo|switch` 전략 봇, `--quit-on-end` 판 끝나면 종료.
## 강화는 판마다 config 복사본에 적용한다 (원본 .tres는 안 바뀜).

const LOG_PATH := "user://rune_log.csv"

@export var config: RuneConfig
@export var upgrade_list: UpgradeList
@export var guide_y: float = 1790.0
@export var guide_size: float = 110.0

@onready var wizard: Wizard = $Wizard
@onready var stroke: StrokeInput = $StrokeInput
@onready var result_label: Label = $HUD/ResultLabel
@onready var detail_label: Label = $HUD/DetailLabel

var dummy: Dummy
var battle: Battle
var stats_label: Label
var recognizer: RuneRecognizer
var _base_config: RuneConfig
var _base_combat: CombatConfig
var _taken := {}  # 강화 id → 횟수
var _offer: Array = []  # 지금 보여주는 강화 3개
var _upgrade_rng := RandomNumberGenerator.new()
var _result_time := 0.0
var _bot := ""
var _quit_on_end := false
var _boss_test_mode := false

func _ready() -> void:
	_base_config = config
	dummy = get_node_or_null("Dummy")
	battle = get_node_or_null("Battle")
	if battle != null:
		_base_combat = battle.combat
	stroke.stroke_started.connect(_on_stroke_started)
	stroke.stroke_finished.connect(_on_stroke_finished)
	stroke.stroke_cancelled.connect(_on_stroke_cancelled)
	var reset := get_node_or_null("HUD/ResetButton")
	if reset != null and dummy != null:
		reset.pressed.connect(dummy.reset_stats)
	for a in OS.get_cmdline_user_args():
		if a == "--autoplay":
			_autoplay()
		elif a.begins_with("--bot="):
			_bot = a.substr(6)
		elif a == "--quit-on-end":
			_quit_on_end = true
		elif a.begins_with("--seed=") and battle != null:
			battle.seed = int(a.substr(7))
		elif a.begins_with("--start-wave=") and battle != null:
			battle.start_wave = int(a.substr(13))
		elif a == "--boss-test":
			_boss_test_mode = true
			_bot = "switch"
	if battle != null:
		stats_label = $HUD/StatsLabel
		$HUD/SlotButton.pressed.connect(_toggle_slots)
		$HUD/InvincibleButton.pressed.connect(_toggle_invincible)
		$HUD/RestartButton.pressed.connect(_restart)
		$HUD/SkipButton.pressed.connect(func(): battle.skip_wave())
		$HUD/ResultPanel/Box/Retry.pressed.connect(_restart)
		for i in 3:
			get_node("HUD/UpgradePanel/Box/Option%d" % i).pressed.connect(_choose.bind(i))
		battle.finished.connect(_on_battle_finished)
		battle.wave_started.connect(_on_wave_started)
		battle.wave_cleared.connect(_on_wave_cleared)
		_new_run()
		if _bot != "":
			_run_bot()
		if _boss_test_mode:
			_boss_test()
	else:
		recognizer = RuneRecognizer.new(config)
	result_label.text = ""
	detail_label.text = "화면 아무 곳에 룬을 한 획으로 그려봐"

## 새 판: 수치 복사본을 만들어 모든 곳에 다시 연결
func _new_run() -> void:
	config = _base_config.duplicate()
	battle.combat = _base_combat.duplicate()
	wizard.config = config
	recognizer = RuneRecognizer.new(config)
	wizard.clear_slots()
	wizard.set_slot_count(config.slot_count)
	_taken.clear()
	_upgrade_rng.seed = battle.seed
	$HUD/UpgradePanel.visible = false
	$HUD/ResultPanel.visible = false
	get_tree().paused = false
	_update_buttons()
	battle.start()

func _process(delta: float) -> void:
	if _result_time > 0.0:
		_result_time -= delta
		result_label.modulate.a = clampf(_result_time, 0.0, 1.0)
	if stats_label != null:
		stats_label.text = _stats_text()

# ---- 획 처리 ----

func _on_stroke_started() -> void:
	if config.slow_while_drawing:
		Engine.time_scale = config.slow_scale

func _on_stroke_cancelled(reason: String) -> void:
	Engine.time_scale = 1.0
	_show("", Color.WHITE, "획 취소: " + reason)
	_log({"tier": "cancel", "reason": reason, "element": Element.NONE, "score": 0.0,
		"second_element": Element.NONE, "second_score": 0.0}, 0)

func _on_stroke_finished(points: PackedVector2Array) -> void:
	Engine.time_scale = 1.0
	if battle != null:
		battle.draws += 1
	var r := recognizer.recognize(points, get_viewport_rect().size.y)
	var tier_name: String = RuneConfig.TIER_NAMES[r.tier]
	var detail := "1등 %s %.2f / 2등 %s %.2f" % [Element.name_of(r.best_element), r.score,
		Element.name_of(r.second_element), r.second_score]
	if r.tier == "fail":
		stroke.flash_result(Color(0.6, 0.6, 0.6))
		if r.score <= 0.0:
			detail = ""
		_show(tier_name, Color(0.75, 0.75, 0.75), r.reason + ("\n" + detail if detail != "" else ""))
	else:
		var kind := wizard.apply_rune(r.element, r.tier)
		var c := Element.color_of(r.element)
		stroke.flash_result(c)
		var extra: String = {"refresh": "시간 갱신", "new": "부여", "replace": "교체"}[kind]
		extra += " %d초" % int(config.duration_for(r.tier))
		if r.tier == "perfect" and kind != "refresh":
			extra += " + 강화탄"
		if r.tier == "perfect" and battle != null and _taken.get("burst", 0) > 0:
			var u := _upgrade("burst")
			var center := Vector2.ZERO
			for p in points:
				center += p
			battle.burst(center / points.size(), r.element, u.amount, u.amount_b)
			extra += " + 폭발"
		_show("%s · %s" % [Element.name_of(r.element), tier_name], c, extra + "\n" + detail)
	_log(r, points.size())

func _show(title: String, color: Color, detail: String) -> void:
	result_label.text = title
	result_label.modulate = color
	_result_time = 1.6
	detail_label.text = detail

func _log(r: Dictionary, point_count: int) -> void:
	var exists := FileAccess.file_exists(LOG_PATH)
	var f := FileAccess.open(LOG_PATH, FileAccess.READ_WRITE if exists else FileAccess.WRITE)
	if f == null:
		return
	if exists:
		f.seek_end()
	else:
		f.store_line("time,tier,element,score,second_element,second_score,reason,points")
	f.store_line("%s,%s,%s,%.3f,%s,%.3f,%s,%d" % [Time.get_datetime_string_from_system(), r.tier,
		Element.name_of(r.element), r.score, Element.name_of(r.second_element), r.second_score, r.reason, point_count])

# ---- 웨이브 · 강화 3택1 ----

func _upgrade(id: String) -> UpgradeData:
	for u in upgrade_list.items:
		if u.id == id:
			return u
	return null

func _on_wave_started(w: int) -> void:
	_show("웨이브 %d" % w, Color(0.95, 0.9, 0.7), "")

func _on_wave_cleared(w: int) -> void:
	stroke.cancel("강화 선택")
	_offer = _make_offer(w)
	if _offer.is_empty():
		battle.next_wave()
		return
	for i in 3:
		var b: Button = get_node("HUD/UpgradePanel/Box/Option%d" % i)
		b.visible = i < _offer.size()
		if i < _offer.size():
			var u: UpgradeData = _offer[i]
			var stack := " (%d/%d)" % [_taken.get(u.id, 0) + 1, u.max_stacks] if u.max_stacks > 1 else ""
			b.text = "%s%s\n%s" % [u.title, stack, u.description]
	$HUD/UpgradePanel/Box/Title.text = "웨이브 %d 클리어 · 강화 선택" % w
	$HUD/UpgradePanel.visible = true
	result_label.text = ""
	detail_label.text = ""
	get_tree().paused = true  # 게임·속성 타이머 정지 (HUD만 동작)
	if _bot != "":
		await get_tree().create_timer(1.5).timeout
		var pick := 0
		for i in _offer.size():
			if _offer[i].id == "slot":
				pick = i
		_choose(pick)

## 남은 강화 중 3개. 정해진 웨이브 이후엔 룬 칸 +1을 반드시 포함.
func _make_offer(w: int) -> Array:
	var pool: Array = []
	var slot_up: UpgradeData = null
	for u in upgrade_list.items:
		if _taken.get(u.id, 0) >= u.max_stacks:
			continue
		if u.id == "slot" and w >= battle.combat.slot_upgrade_from_wave:
			slot_up = u
		else:
			pool.append(u)
	var out: Array = []
	if slot_up != null:
		out.append(slot_up)
	while out.size() < 3 and not pool.is_empty():
		out.append(pool.pop_at(_upgrade_rng.randi_range(0, pool.size() - 1)))
	return out

func _choose(i: int) -> void:
	if i >= _offer.size() or not $HUD/UpgradePanel.visible:
		return
	var u: UpgradeData = _offer[i]
	_taken[u.id] = _taken.get(u.id, 0) + 1
	_apply_upgrade(u)
	$HUD/UpgradePanel.visible = false
	get_tree().paused = false
	battle.next_wave()

func _apply_upgrade(u: UpgradeData) -> void:
	var c := battle.combat
	match u.id:
		"burn":
			c.burn_dps *= 1.0 + u.amount
		"slow":
			c.slow_factor = maxf(c.slow_factor - u.amount, 0.1)
			c.slow_duration += u.amount_b
		"chain":
			c.chain_count += int(u.amount)
		"duration":
			for k in config.tier_durations.size():
				config.tier_durations[k] += u.amount
		"attack_speed":
			config.fire_interval *= 1.0 - u.amount
		"perfect_range":
			config.tier_thresholds[3] = maxf(config.tier_thresholds[3] - u.amount, config.tier_thresholds[2] + 0.01)
		"slot":
			wizard.set_slot_count(mini(wizard.slots.size() + int(u.amount), 2))
			_update_buttons()
		"burst":
			pass  # 획 판정에서 처리

# ---- 디버그 패널 ----

func _stats_text() -> String:
	var b := battle
	var minutes := maxf(b.elapsed / 60.0, 0.01)
	var ups := []
	for id in _taken.keys():
		var u := _upgrade(id)
		ups.append("%s%s" % [u.title, " x%d" % _taken[id] if _taken[id] > 1 else ""])
	return "시간 %d초  처치 %d  누수 %d\n피해 직접 %d · 화상 %d · 연쇄 %d · 반응 %d · 폭발 %d\n반응 증기 %d · 전파 %d · 빙결 %d\n분당 그리기 %.1f (총 %d)\n강화: %s" % [
		int(b.elapsed), b.kills, b.leaks,
		int(b.stats.direct), int(b.stats.burn), int(b.stats.chain), int(b.stats.reaction), int(b.stats.burst),
		b.reaction_counts["증기 폭발"], b.reaction_counts["화상 전파"], b.reaction_counts["빙결"],
		b.draws / minutes, b.draws, ", ".join(ups) if not ups.is_empty() else "없음"]

func _toggle_slots() -> void:
	wizard.set_slot_count(1 if wizard.slots.size() >= 2 else 2)
	_update_buttons()

func _toggle_invincible() -> void:
	battle.invincible = not battle.invincible
	_update_buttons()

func _restart() -> void:
	stroke.cancel("다시 시작")
	result_label.text = ""
	_new_run()

func _update_buttons() -> void:
	$HUD/SlotButton.text = "속성 칸 %d" % wizard.slots.size()
	$HUD/InvincibleButton.text = "무적 켜짐" if battle.invincible else "무적 꺼짐"

func _on_battle_finished(won: bool) -> void:
	stroke.cancel("전투 종료")
	_show(battle.result_text, Color(0.6, 1.0, 0.6) if won else Color(1.0, 0.5, 0.5),
		"웨이브 %d에서 끝 · 다시 시작 버튼으로 재도전" % battle.wave)
	_result_time = 0.0
	_show_result_panel(won)
	var line := "[battle] bot=%s won=%s wave=%d castle=%d time=%d kills=%d leaks=%d direct=%d burn=%d chain=%d reaction=%d burst=%d steam=%d spread=%d freeze=%d draws=%d ups=%s" % [
		_bot, won, battle.wave, battle.castle_hp, int(battle.elapsed), battle.kills, battle.leaks,
		int(battle.stats.direct), int(battle.stats.burn), int(battle.stats.chain), int(battle.stats.reaction), int(battle.stats.burst),
		battle.reaction_counts["증기 폭발"], battle.reaction_counts["화상 전파"], battle.reaction_counts["빙결"], battle.draws, _taken]
	print(line)
	if _quit_on_end:
		get_tree().quit()

# ---- 전략 봇 (같은 판을 세 방식으로 비교) ----
## fire: 불만 유지 / duo: 불만 쓰다가 룬 칸 +1 뒤 불+번개 고정 / switch: 상황 따라 교체. 셋 다 같은 강화 규칙·시드.
## 강화는 룬 칸 +1이 있으면 그것, 없으면 첫 번째를 고른다.

func _run_bot() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = battle.seed + 99
	var last_draw := -10.0
	while true:
		await get_tree().create_timer(0.25, false).timeout
		if not battle.fighting:
			continue
		if battle.elapsed - last_draw < 1.0:
			continue
		var want := _bot_choice()
		if want == Element.NONE:
			continue
		await get_tree().create_timer(rng.randf_range(0.5, 1.0), false).timeout  # decision delay
		want = _bot_choice()
		if want == Element.NONE or not battle.fighting:
			continue
		last_draw = battle.elapsed
		await _bot_draw(want, rng)

func _bot_choice() -> int:
	match _bot:
		"fire":
			return Element.FIRE if wizard.remaining_of(Element.FIRE) < 1.0 else Element.NONE
		"duo":
			if wizard.slots.size() < 2:  # before slot upgrade: fire only
				return Element.FIRE if wizard.remaining_of(Element.FIRE) < 1.0 else Element.NONE
			for e in [Element.FIRE, Element.LIGHTNING]:
				if wizard.remaining_of(e) < 1.0:
					return e
			return Element.NONE
		"switch":
			var want := _situation()
			return want if wizard.remaining_of(want) < 1.0 else Element.NONE
	return Element.NONE

## 지금 상황에 유리한 속성: 가까운 돌진형 → 얼음, 뭉친 떼 → 번개, 탱커 → 불
func _situation() -> int:
	var enemies := battle.active_enemies()
	var boss_e: Enemy = null
	for e in enemies:
		if e.is_boss:
			boss_e = e
	if boss_e != null:
		if boss_e.shield_active():
			var pair := [Element.FIRE, Element.ICE, Element.LIGHTNING]
			pair.erase(boss_e.shield_element)
			for el in pair:
				if not _has_status(boss_e, el):
					return el
			return pair[0]
		if boss_e.charge_phase != 0:
			return Element.ICE
		for t in boss_e.traits:
			if t.id == "regen" and boss_e.burn_t <= 0.0:
				return Element.FIRE
	var best_cluster := 0
	var has_tank := false
	for e in enemies:
		if e.data == battle.runner and e.position.y > 650.0:
			return Element.ICE
		if e.data == battle.tank and e.position.y > 250.0:
			has_tank = true
		if e.data == battle.swarm:
			var n := 0
			for o in enemies:
				if o.position.distance_to(e.position) < 200.0:
					n += 1
			best_cluster = maxi(best_cluster, n)
	if best_cluster >= 5:
		return Element.LIGHTNING
	if has_tank:
		return Element.FIRE
	return Element.LIGHTNING if enemies.size() >= 4 else Element.FIRE

func _bot_draw(e: int, rng: RandomNumberGenerator) -> void:
	var shape: PackedVector2Array = RuneRecognizer.shapes()[e].duplicate()
	var warp := rng.randf_range(0.0, 0.14)
	for i in shape.size():
		shape[i] += Vector2(rng.randf_range(-warp, warp), rng.randf_range(-warp, warp))
	var pts := _make_stroke(shape, Vector2(540, 900), 340.0, 7.0, rng)
	var dur := 0.6
	var t := 0.0
	var i := 1
	stroke.begin(pts[0])
	while i < pts.size() and stroke.drawing:
		await get_tree().process_frame
		t += get_process_delta_time()
		var upto := mini(int(t / dur * pts.size()) + 1, pts.size())
		while i < upto:
			stroke.add_point(pts[i])
			i += 1
	stroke.finish()


func _has_status(e: Enemy, el: int) -> bool:
	match el:
		Element.FIRE:
			return e.burn_t > 0.0
		Element.ICE:
			return e.slow_t > 0.0
		Element.LIGHTNING:
			return e.shock_t > 0.0
	return false

# ---- 결과 화면 ----

func _show_result_panel(won: bool) -> void:
	var b := battle
	var ups := []
	for id in _taken.keys():
		var u := _upgrade(id)
		ups.append("%s%s" % [u.title, " x%d" % _taken[id] if _taken[id] > 1 else ""])
	$HUD/ResultPanel/Box/Title.text = "승리" if won else "패배"
	$HUD/ResultPanel/Box/Body.text = "도달 웨이브 %d / %d\n시간 %d초 · 처치 %d · 누수 %d · 성 %d\n\n피해\n직접 %d · 화상 %d · 연쇄 %d\n반응 %d · 폭발 %d\n반응 횟수: 증기 %d · 전파 %d · 빙결 %d\n\n강화: %s" % [
		b.wave, b.combat.wave_count, int(b.elapsed), b.kills, b.leaks, b.castle_hp,
		int(b.stats.direct), int(b.stats.burn), int(b.stats.chain), int(b.stats.reaction), int(b.stats.burst),
		b.reaction_counts["증기 폭발"], b.reaction_counts["화상 전파"], b.reaction_counts["빙결"],
		", ".join(ups) if not ups.is_empty() else "없음"]
	$HUD/ResultPanel.visible = true
	result_label.text = ""
	detail_label.text = ""

# ---- 보스 조합 검사 (`-- --boss-test`) ----
## 조합마다 보스 하나만 띄워 switch 봇으로 상대하고, 처치 시간·방패 파괴·체력 정체·소환 상한을 찍는다.

func _boss_test() -> void:
	battle.test_mode = true
	battle.invincible = true
	wizard.set_slot_count(2)
	var tr := {}
	for t in battle.boss_traits.items:
		tr[t.id] = t
	var defs := [["shield", Element.FIRE], ["shield", Element.ICE], ["shield", Element.LIGHTNING], ["regen", 0], ["", 0]]
	var acts := ["summon", "charge", ""]
	var mult: float = battle.combat.boss_hp_multipliers[1]
	for d in defs:
		for a in acts:
			if d[0] == "" and a == "":
				continue
			var traits: Array = []
			if d[0] != "":
				traits.append(tr[d[0]])
			if a != "":
				traits.append(tr[a])
			wizard.clear_slots()
			var leaks0 := battle.leaks
			var cap0 := battle.summon_cap_hits
			var boss := battle.spawn_test_boss(traits, d[1], mult)
			var t := 0.0
			var breaks := 0
			var was_broken := false
			var samples: Array = []
			var stall := 0
			var next_sample := 1.0
			while boss.active and boss.is_boss and t < 90.0:
				await get_tree().process_frame
				t += get_process_delta_time()
				var broken := boss.shield_broken_t > 0.0
				if broken and not was_broken:
					breaks += 1
				was_broken = broken
				if t >= next_sample:
					next_sample += 1.0
					samples.append(boss.hp)
					if samples.size() > 10 and boss.hp >= samples[samples.size() - 11]:
						stall += 1
			var killed := not boss.active and battle.leaks == leaks0
			var dname: String = "%s(%s)" % [d[0], Element.name_of(d[1])] if d[0] == "shield" else (d[0] if d[0] != "" else "-")
			print("[combo] defense=%s action=%s killed=%s time=%d breaks=%d stall=%ds summon_cap=%d leak=%s" % [
				dname, a if a != "" else "-", killed, int(t), breaks, stall, battle.summon_cap_hits - cap0, battle.leaks > leaks0])
	get_tree().quit()

# ---- 룬 안내 (화면 하단) ----

func _draw() -> void:
	var shapes := RuneRecognizer.shapes()
	var order := [Element.FIRE, Element.ICE, Element.LIGHTNING]
	var font := ThemeDB.fallback_font
	for i in order.size():
		var e: int = order[i]
		var cx := 270.0 + i * 270.0
		var origin := Vector2(cx - guide_size / 2, guide_y - guide_size / 2)
		var pts := PackedVector2Array()
		for p in shapes[e]:
			pts.append(origin + p * guide_size)
		var c := Element.color_of(e)
		draw_rect(Rect2(origin - Vector2(20, 20), Vector2(guide_size + 40, guide_size + 40)), Color(1, 1, 1, 0.06))
		draw_polyline(pts, c, 7, true)
		draw_circle(pts[0], 10, Color.WHITE)
		draw_string(font, Vector2(cx - 80, guide_y + guide_size / 2 + 55), Element.name_of(e),
			HORIZONTAL_ALIGNMENT_CENTER, 160, 34, c)

# ---- 자동 재생 (화면 확인용) ----

func _autoplay() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var shapes := RuneRecognizer.shapes()
	var plan := [
		[shapes[Element.FIRE], 1.2],
		[shapes[Element.ICE], 2.4],
		[shapes[Element.LIGHTNING], 2.4],
		[PackedVector2Array([Vector2(0, 0.5), Vector2(1, 0.5)]), 2.4],
	]
	for step in plan:
		await get_tree().create_timer(step[1]).timeout
		var pts := _make_stroke(step[0], Vector2(540, 1050), 370.0, 7.0, rng)
		stroke.begin(pts[0])
		for i in range(1, pts.size()):
			stroke.add_point(pts[i])
			if i % 3 == 0:
				await get_tree().process_frame
		stroke.finish()
	await get_tree().create_timer(2.0).timeout
	var pts2 := _make_stroke(shapes[Element.FIRE], Vector2(540, 1050), 370.0, 6.0, rng)
	stroke.begin(pts2[0])
	for i in range(1, pts2.size() / 2):
		stroke.add_point(pts2[i])
		if i % 3 == 0:
			await get_tree().process_frame
	stroke.cancel("두 번째 손가락")

func _make_stroke(shape: PackedVector2Array, center: Vector2, size: float, jitter: float,
		rng: RandomNumberGenerator) -> PackedVector2Array:
	var out := PackedVector2Array()
	var origin := center - Vector2(size, size) / 2.0
	for i in range(shape.size() - 1):
		var seg := shape[i].distance_to(shape[i + 1]) * size
		var n := maxi(int(seg / 12.0), 2)
		for k in range(n):
			var p := origin + shape[i].lerp(shape[i + 1], float(k) / n) * size
			out.append(p + Vector2(rng.randf_range(-jitter, jitter), rng.randf_range(-jitter, jitter)))
	out.append(origin + shape[shape.size() - 1] * size)
	return out
