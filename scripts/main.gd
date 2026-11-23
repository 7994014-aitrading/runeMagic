extends Node2D
## 메인: 획 입력 → 인식 → 마법사 속성 칸 적용, 판정 표시, 로그, 룬 안내.
## Battle 노드가 있으면 웨이브 전투 + 강화 3택1 + 디버그 패널, Dummy 노드가 있으면 허수아비 시험.
## 실행 인자: `-- --autoplay` 정해둔 획 자동 재생, `-- --bot=fire|duo|switch` 전략 봇, `--quit-on-end` 판 끝나면 종료.
## 강화는 판마다 config 복사본에 적용한다 (원본 .tres는 안 바뀜).
## GameState.current_stage가 있으면 그 스테이지(10웨이브·난이도·해금 룬·영구 강화·튜토리얼)로,
## 없으면(장면 직접 실행) 예전 15웨이브 시험 판. `-- --stage=N`은 봇용: 그 스테이지 수치, 룬 전부, 영구 강화·튜토리얼 없음.

const LOG_PATH := "user://rune_log.csv"
const BASE_HEIGHT := 1920.0  # project.godot 기준 높이. 폰이 더 길면 남는 높이만큼 전장이 위로 늘어난다.
## 세로로 긴 화면: 아래 UI는 화면 바닥에, 가운데 패널은 가운데에, 위 디버그는 위에 붙인다.
const HUD_FOLLOW_BOTTOM := ["ResultLabel", "DetailLabel"]
const HUD_FOLLOW_CENTER := ["UpgradePanel", "ResultPanel"]

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
var _hud_base_top := {}  # HUD 이름 → 기준 화면에서의 y
var _stage := 0  # 0 = 스테이지 없음 (시험 판)
var _sim := false  # --stage 봇 실행: 저장·영구 강화·튜토리얼 안 씀
var _seed_given := false
var _sim_perm := 0  # --perm=N: 봇이 영구 강화를 전부 N레벨(상한까지) 가진 것으로
var _runes: Array = [Element.FIRE, Element.ICE, Element.LIGHTNING]  # 이번 판에 쓸 수 있는 룬
var _offer_context := "wave"  # "wave" / "start"
var _pause_panel: Control
var _settings_panel: Control
var _pause_button: Button
var _stage_label: Label
var _stars_label: Label
var _next_button: Button
var _map_button: Button
var _hint_panel: PanelContainer
var _hint_label: Label
var _hint_time := 0.0
var _await_rune := Element.NONE  # 튜토리얼: 이 룬을 그릴 때까지 전장 정지
var _guide_t := 0.0

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
			_seed_given = true
		elif a.begins_with("--perm="):
			_sim_perm = int(a.substr(7))
		elif a.begins_with("--stage="):
			_stage = int(a.substr(8))
			_sim = true
		elif a.begins_with("--start-wave=") and battle != null:
			battle.start_wave = int(a.substr(13))
		elif a == "--boss-test":
			_boss_test_mode = true
			_bot = "switch"
	if battle != null and _stage == 0 and _bot == "" and not _boss_test_mode:
		_stage = GameState.current_stage
	if battle != null:
		_build_battle_hud()
		stats_label = $HUD/StatsLabel
		$HUD/SlotButton.pressed.connect(_toggle_slots)
		$HUD/InvincibleButton.pressed.connect(_toggle_invincible)
		$HUD/RestartButton.pressed.connect(_restart)
		$HUD/SkipButton.pressed.connect(func(): battle.skip_wave())
		$HUD/ResultPanel/Box/Retry.pressed.connect(_restart)
		$HUD/ResultPanel/Box/Retry.text = "다시 도전"
		battle.reaction_triggered.connect(_on_reaction)
		battle.boss_spawned.connect(_on_boss_spawned)
		battle.castle_hit.connect(func(_d):
			GameState.vibrate(40)
			GameState.sfx("castle"))
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
		_runes = GameState.runes()
		recognizer = RuneRecognizer.new(config, _runes)
		_add_practice_back()
	result_label.text = ""
	detail_label.text = "화면 아무 곳에 룬을 한 획으로 그려봐"
	for n in HUD_FOLLOW_BOTTOM + HUD_FOLLOW_CENTER:
		var c := get_node_or_null("HUD/" + n) as Control
		if c != null:
			_hud_base_top[n] = c.position.y
	get_viewport().size_changed.connect(_fit_screen)
	_fit_screen()

func _fit_screen() -> void:
	var extra := maxf(get_viewport_rect().size.y - BASE_HEIGHT, 0.0)
	position.y = extra  # 월드 전체를 내려 성·마법사·룬 안내가 화면 바닥에 붙게
	if battle != null:
		battle.set_field_extra(extra)
	for n in _hud_base_top:
		var c := get_node("HUD/" + n) as Control
		c.position.y = _hud_base_top[n] + (extra if n in HUD_FOLLOW_BOTTOM else extra * 0.5)

## 새 판: 수치 복사본을 만들어 모든 곳에 다시 연결
func _new_run() -> void:
	config = _base_config.duplicate(true)
	battle.combat = _base_combat.duplicate(true)
	wizard.config = config
	if _stage > 0:
		_apply_stage()
	if _stage == 0:
		_runes = [Element.FIRE, Element.ICE, Element.LIGHTNING]
	elif _sim:
		_runes = GameState.chapter.runes_at(_stage)  # 봇: 그 스테이지를 처음 할 때의 룬
	else:
		_runes = GameState.runes()
	battle.allow_shield = _runes.size() >= 3
	recognizer = RuneRecognizer.new(config, _runes)
	wizard.clear_slots()
	wizard.set_slot_count(config.slot_count)
	_taken.clear()
	_upgrade_rng.seed = battle.seed
	$HUD/UpgradePanel.visible = false
	$HUD/ResultPanel.visible = false
	_close_pause()
	_set_await(Element.NONE)
	_hint("", 0.0)
	get_tree().paused = false
	_update_buttons()
	_apply_dev_visibility()
	queue_redraw()
	battle.start()
	GameState.music("battle")
	if _stage > 0 and not _sim and GameState.perm_level("start_pick") > 0:
		_offer_upgrades("start", 0)

## 스테이지 수치: 10웨이브, 마지막 보스, 난이도 배율, 영구 강화
func _apply_stage() -> void:
	var ch := GameState.chapter
	var c := battle.combat
	c.wave_count = ch.waves_per_stage
	c.boss_waves = PackedInt32Array([ch.waves_per_stage])
	c.boss_hp_multipliers = PackedFloat32Array([ch.boss_hp_mult(_stage)])
	c.boss_trait_counts = PackedInt32Array([ch.boss_traits(_stage)])
	var bm := ch.budget_mult(_stage)
	c.budget_base *= bm
	c.budget_per_wave *= bm
	battle.enemy_hp_mult = ch.enemy_hp_mult(_stage)
	if not _seed_given:
		battle.seed = ch.stage_seed(_stage)
	var pv := func(id: String) -> float:
		if not _sim:
			return GameState.perm_value(id)
		var u := GameState.perm(id)
		return u.amount * mini(_sim_perm, u.max_stacks)
	config.base_damage *= 1.0 + pv.call("attack")
	c.castle_hp += int(pv.call("castle"))
	for k in config.tier_durations.size():
		config.tier_durations[k] += pv.call("duration")

func _process(delta: float) -> void:
	if _hint_time > 0.0:
		_hint_time -= delta
		if _hint_time <= 0.0 and _hint_panel != null:
			_hint_panel.visible = false
	if _await_rune != Element.NONE:
		_guide_t += delta
		queue_redraw()
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
	var r := recognizer.recognize(points, BASE_HEIGHT)  # 화면 폭은 고정이라 기준 높이로 판정
	var tier_name: String = RuneConfig.TIER_NAMES[r.tier]
	var detail := "1등 %s %.2f / 2등 %s %.2f" % [Element.name_of(r.best_element), r.score,
		Element.name_of(r.second_element), r.second_score]
	if not _dev():
		detail = "점수 %d" % int(round(r.score * 100)) if r.score > 0.0 else ""
	if r.tier == "fail":
		GameState.sfx("fail")
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
		GameState.sfx("cast", 3.0 if r.tier == "perfect" else 0.0)
		if r.tier == "perfect":
			GameState.vibrate(15)
		_tutorial_rune_drawn(r.element)
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


func _on_wave_cleared(w: int) -> void:
	_offer_upgrades("wave", w)

## 강화 3택1 창. context "start"면 판 시작 강화(영구 강화 '시작 강화'), 고른 뒤 웨이브를 넘기지 않는다.
func _offer_upgrades(context: String, w: int) -> void:
	_offer_context = context
	stroke.cancel("강화 선택")
	_offer = _make_offer(maxi(w, 1))
	if _offer.is_empty():
		if context == "wave":
			battle.next_wave()
		return
	for i in 3:
		var b: Button = get_node("HUD/UpgradePanel/Box/Option%d" % i)
		b.visible = i < _offer.size()
		if i < _offer.size():
			var u: UpgradeData = _offer[i]
			var stack := " (%d/%d)" % [_taken.get(u.id, 0) + 1, u.max_stacks] if u.max_stacks > 1 else ""
			b.text = "%s%s\n%s" % [u.title, stack, u.description]
	var title := "시작 강화 선택" if context == "start" else "웨이브 %d 클리어 · 강화 선택" % w
	if not _sim and not GameState.tutorial_done("upgrade"):
		title += "\n웨이브를 깰 때마다 강화를 하나 고릅니다"
	$HUD/UpgradePanel/Box/Title.text = title
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
		if _taken.get(u.id, 0) >= u.max_stacks or not _upgrade_allowed(u):
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
	GameState.sfx("upgrade")
	$HUD/UpgradePanel.visible = false
	get_tree().paused = _pause_panel != null
	if not _sim and not GameState.tutorial_done("upgrade"):
		GameState.mark_tutorial("upgrade")
	if u.id == "slot" and not _sim and not GameState.tutorial_done("slot"):
		GameState.mark_tutorial("slot")
		_hint("룬 칸 2개: 두 속성을 번갈아 쏩니다. 한 적에게 두 속성이 붙으면 반응이 터져요.", 6.0)
	if _offer_context == "wave":
		battle.next_wave()

## 해금 안 된 룬 전용 강화는 빼고, 룬 칸 +1은 룬이 2개 이상일 때만
func _upgrade_allowed(u: UpgradeData) -> bool:
	match u.id:
		"burn":
			return _runes.has(Element.FIRE)
		"slow":
			return _runes.has(Element.ICE)
		"chain":
			return _runes.has(Element.LIGHTNING)
		"slot":
			return _runes.size() >= 2
	return true

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
	_close_pause()
	result_label.text = ""
	_new_run()

func _update_buttons() -> void:
	$HUD/SlotButton.text = "속성 칸 %d" % wizard.slots.size()
	$HUD/InvincibleButton.text = "무적 켜짐" if battle.invincible else "무적 꺼짐"

func _on_battle_finished(won: bool) -> void:
	stroke.cancel("전투 종료")
	_close_pause()
	_set_await(Element.NONE)
	_hint("", 0.0)
	GameState.music("")
	GameState.sfx("win" if won else "lose")
	result_label.text = ""
	detail_label.text = ""
	_result_time = 0.0
	_show_result_panel(won)
	var line := "[battle] stage=%d bot=%s won=%s wave=%d castle=%d time=%d kills=%d leaks=%d direct=%d burn=%d chain=%d reaction=%d burst=%d steam=%d spread=%d freeze=%d draws=%d ups=%s" % [
		_stage, _bot, won, battle.wave, battle.castle_hp, int(battle.elapsed), battle.kills, battle.leaks,
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
			if not _runes.has(want):
				want = Element.FIRE if wizard.remaining_of(Element.FIRE) < 1.0 or _runes.size() == 1 else _runes[_runes.size() - 1]
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
	var ratio := float(b.castle_hp) / maxf(b.combat.castle_hp, 1.0)
	var lines := []
	var stars := 0
	if _stage > 0 and not _sim:
		var res := GameState.record_result(_stage, won, b.wave, ratio)
		stars = res.stars
		lines.append("스테이지 %s · 웨이브 %d / %d" % [GameState.chapter.stage_name(_stage), b.wave, b.combat.wave_count])
		lines.append("마력석 +%d%s  (보유 %d)" % [res.stones, " · 첫 클리어 보너스 포함" if res.first_clear else "", GameState.data.stones])
		for e in res.new_runes:
			lines.append("새 룬 해금: %s" % Element.name_of(e))
		if res.first_clear and _stage < GameState.chapter.stage_count:
			lines.append("스테이지 %s 열림" % GameState.chapter.stage_name(_stage + 1))
	else:
		stars = GameState.chapter.stars_for(ratio) if won else 0
		lines.append("도달 웨이브 %d / %d" % [b.wave, b.combat.wave_count])
	lines.append("처치 %d · 놓침 %d · 성 %d / %d · %d초" % [b.kills, b.leaks, b.castle_hp, b.combat.castle_hp, int(b.elapsed)])
	if _dev():
		var ups := []
		for id in _taken.keys():
			var u := _upgrade(id)
			ups.append("%s%s" % [u.title, " x%d" % _taken[id] if _taken[id] > 1 else ""])
		lines.append("\n피해 직접 %d · 화상 %d · 연쇄 %d · 반응 %d · 폭발 %d\n반응 증기 %d · 전파 %d · 빙결 %d\n강화: %s" % [
			int(b.stats.direct), int(b.stats.burn), int(b.stats.chain), int(b.stats.reaction), int(b.stats.burst),
			b.reaction_counts["증기 폭발"], b.reaction_counts["화상 전파"], b.reaction_counts["빙결"],
			", ".join(ups) if not ups.is_empty() else "없음"])
	$HUD/ResultPanel/Box/Title.text = "승리" if won else "패배"
	$HUD/ResultPanel/Box/Title.modulate = UI.GOOD if won else UI.BAD
	_stars_label.text = UI.stars_text(stars) if won else ""
	_stars_label.visible = won
	$HUD/ResultPanel/Box/Body.text = "\n".join(lines)
	_next_button.visible = won and _stage > 0 and not _sim and _stage < GameState.chapter.stage_count
	_map_button.visible = not _sim
	_map_button.text = "맵으로" if _stage > 0 else "메뉴로"
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
	var order := _runes
	var font := UI.font()
	if _await_rune != Element.NONE:
		# 튜토리얼: 화면 가운데 큰 안내선 (흰 점에서 시작)
		var a := 0.35 + 0.25 * sin(_guide_t * 3.0)
		draw_circle(Vector2(540, 760), 300, Color(1, 1, 1, 0.04))
		UI.draw_rune(self, _await_rune, Vector2(540, 760), 420, 18.0, a + 0.3)
	for i in order.size():
		var e: int = order[i]
		var cx := 540.0 + (i - (order.size() - 1) / 2.0) * 270.0
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

# ---- 스테이지 HUD: 일시정지 · 결과 버튼 · 안내 · 개발자 표시 ----

func _dev() -> bool:
	return _stage == 0 or _sim or GameState.setting("dev")

func _build_battle_hud() -> void:
	var hud: CanvasLayer = $HUD
	var rp: Control = $HUD/ResultPanel
	rp.offset_top = 260.0
	rp.offset_bottom = 1400.0
	var box: VBoxContainer = $HUD/ResultPanel/Box
	_stars_label = UI.label("", 96, UI.STAR_ON)
	box.add_child(_stars_label)
	box.move_child(_stars_label, 1)
	_next_button = UI.button("다음 스테이지", 120, 44)
	_next_button.pressed.connect(func(): GameState.start_stage(_stage + 1))
	box.add_child(_next_button)
	box.move_child(_next_button, $HUD/ResultPanel/Box/Retry.get_index())
	_map_button = UI.button("맵으로", 110, 40)
	_map_button.pressed.connect(_leave)
	box.add_child(_map_button)
	for b in [_next_button, $HUD/ResultPanel/Box/Retry, _map_button]:
		b.theme = UI.theme()
	_pause_button = UI.button("II", 110, 44)
	_pause_button.theme = UI.theme()
	_pause_button.position = Vector2(950, 20)
	_pause_button.size = Vector2(110, 110)
	_pause_button.pressed.connect(_open_pause)
	hud.add_child(_pause_button)
	_stage_label = UI.label("", 36, UI.DIM)
	_stage_label.position = Vector2(290, 50)
	_stage_label.size = Vector2(500, 60)
	_stage_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(_stage_label)
	_hint_panel = PanelContainer.new()
	var sb := UI.box(Color(0.08, 0.08, 0.12, 0.88), UI.GOLD, 18, 3)
	sb.set_content_margin_all(26)
	_hint_panel.add_theme_stylebox_override("panel", sb)
	_hint_panel.position = Vector2(60, 340)
	_hint_panel.custom_minimum_size = Vector2(960, 0)
	_hint_panel.size = Vector2(960, 0)
	_hint_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hint_panel.visible = false
	_hint_label = UI.label("", 36)
	_hint_label.custom_minimum_size = Vector2(900, 0)  # 자동 줄바꿈 폭 (없으면 글자마다 줄이 바뀌어 창이 길어짐)
	_hint_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hint_panel.add_child(_hint_label)
	hud.add_child(_hint_panel)

func _apply_dev_visibility() -> void:
	var dev := _dev()
	$HUD/StatsLabel.visible = dev
	var y := 150.0
	for n in ["SlotButton", "InvincibleButton", "SkipButton", "RestartButton"]:
		var b: Control = get_node("HUD/" + n)
		b.visible = dev
		b.position.y = y
		y += 78.0
	if _stage_label != null:
		_stage_label.text = "스테이지 " + GameState.chapter.stage_name(_stage) if _stage > 0 else ""

func _hint(text: String, secs := 5.0) -> void:
	if _hint_panel == null:
		return
	_hint_label.text = text
	_hint_panel.visible = text != ""
	_hint_panel.reset_size.call_deferred()  # 글 길이에 맞춰 높이를 다시 잡는다
	_hint_time = secs if secs > 0.0 else 0.0

func _leave() -> void:
	GameState.go(GameState.SCENE_MAP if _stage > 0 else GameState.SCENE_TITLE)

func _open_pause() -> void:
	if _pause_panel != null or $HUD/ResultPanel.visible or not battle.running:
		return
	stroke.cancel("일시정지")
	get_tree().paused = true
	var o := UI.overlay($HUD, 760.0)
	_pause_panel = o[0]
	var vb: VBoxContainer = o[1]
	vb.add_child(UI.label("일시정지", 60, UI.GOLD))
	var resume := UI.button("계속", 130, 48)
	resume.pressed.connect(_close_pause)
	vb.add_child(resume)
	var retry := UI.button("다시 시작")
	retry.pressed.connect(_restart)
	vb.add_child(retry)
	var settings := UI.button("설정")
	settings.pressed.connect(func():
		_settings_panel = SettingsPanel.open($HUD, func():
			_settings_panel = null
			_apply_dev_visibility()))
	vb.add_child(settings)
	var leave := UI.button("맵으로 (포기)" if _stage > 0 else "메뉴로 (포기)")
	leave.pressed.connect(_leave)
	vb.add_child(leave)

func _close_pause() -> void:
	if _settings_panel != null:
		_settings_panel.queue_free()
		_settings_panel = null
	if _pause_panel == null:
		return
	_pause_panel.queue_free()
	_pause_panel = null
	get_tree().paused = $HUD/UpgradePanel.visible

func _notification(what: int) -> void:
	if battle == null:
		if what == NOTIFICATION_WM_GO_BACK_REQUEST and dummy != null:
			GameState.go(GameState.SCENE_TITLE)
		return
	match what:
		NOTIFICATION_WM_GO_BACK_REQUEST:
			if _settings_panel != null:
				_settings_panel.queue_free()
				_settings_panel = null
				_apply_dev_visibility()
			elif _pause_panel != null:
				_close_pause()
			elif $HUD/ResultPanel.visible:
				_leave()
			else:
				_open_pause()
		NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_APPLICATION_PAUSED:
			if _bot == "" and not _sim:
				_open_pause()

func _add_practice_back() -> void:
	var b := UI.button("‹ 메뉴", 100, 36)
	b.theme = UI.theme()
	b.position = Vector2(30, 30)
	b.size = Vector2(200, 100)
	b.pressed.connect(func(): GameState.go(GameState.SCENE_TITLE))
	$HUD.add_child(b)

# ---- 튜토리얼 (스테이지 1~3 첫 판: 새 룬을 그릴 때까지 전장 정지) ----

const TUTORIAL := {
	1: [Element.FIRE, "s1", "불 룬 ∧ 을 그려 보세요\n흰 점에서 시작해 손을 떼지 않고 한 번에",
		"불 속성이 기본 공격에 붙었어요! 화상은 계속 피해를 줍니다.\n게이지가 끝나기 전에 다시 그려 갱신하세요."],
	2: [Element.ICE, "s2", "새 룬: 얼음 ○\n흰 점에서 시작해 동그랗게 한 번에",
		"얼음은 적을 느리게 해요. 화상 걸린 적에게 얼음을 맞히면 증기 폭발!\n불과 얼음을 번갈아 그려 보세요."],
	3: [Element.LIGHTNING, "s3", "새 룬: 번개 Z\n흰 점에서 시작해 한 번에",
		"번개는 근처 적에게 튑니다.\n감속된 적에 번개 → 빙결, 화상 걸린 적에 번개 → 화상 전파."],
}

func _on_wave_started(w: int) -> void:
	_show("웨이브 %d" % w, Color(0.95, 0.9, 0.7), "")
	if w == 1 and not _sim and TUTORIAL.has(_stage):
		var t: Array = TUTORIAL[_stage]
		if not GameState.tutorial_done(t[1]) and _runes.has(t[0]):
			_set_await(t[0])
			_hint(t[2], 0.0)

func _set_await(e: int) -> void:
	_await_rune = e
	_guide_t = 0.0
	var mode := Node.PROCESS_MODE_DISABLED if e != Element.NONE else Node.PROCESS_MODE_INHERIT
	for n in [battle, wizard, get_node_or_null("Projectiles")]:
		if n != null:
			n.process_mode = mode
	queue_redraw()

func _tutorial_rune_drawn(e: int) -> void:
	if _await_rune == Element.NONE:
		return
	var t: Array = TUTORIAL[_stage]
	if e != _await_rune:
		_hint("안내된 룬(%s)을 그려 보세요\n" % Element.name_of(_await_rune) + t[2], 0.0)
		return
	_set_await(Element.NONE)
	GameState.mark_tutorial(t[1])
	_hint(t[3], 7.0)

func _on_reaction(rname: String) -> void:
	if _sim or rname != "증기 폭발" or GameState.tutorial_done("steam"):
		return
	GameState.mark_tutorial("steam")
	_hint("증기 폭발! 반응은 넓은 범위에 큰 피해를 줍니다.", 4.0)

func _on_boss_spawned(e: Enemy) -> void:
	GameState.music("boss")
	GameState.sfx("boss")
	if _sim:
		return
	if e.shield_element != Element.NONE and not GameState.tutorial_done("shield"):
		GameState.mark_tutorial("shield")
		_hint("방패 보스! 방패 색(%s) 속성은 막힙니다.\n나머지 두 속성으로 반응을 3번 일으키면 방패가 깨집니다." % Element.name_of(e.shield_element), 8.0)
	elif not GameState.tutorial_done("boss"):
		GameState.mark_tutorial("boss")
		_hint("보스 등장! 체력이 많아요.\n완벽 판정으로 그리면 2배 피해 강화탄이 나갑니다.", 6.0)
