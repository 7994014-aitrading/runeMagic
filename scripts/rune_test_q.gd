extends Node2D
## $Q 허수아비 시험 장면: 여러 획 룬 → 인식 → 속성 있는 룬이면 마법사 속성 칸 적용.
## 실행 인자 `-- --autoplay` 로 정해둔 룬을 자동으로 그린다 (화면 확인용).

const LOG_PATH := "user://rune_log_q.csv"

@export var config: RuneConfig
@export var guide_y: float = 1800.0
@export var guide_size: float = 72.0
@export var guide_gap: float = 112.0

@onready var wizard: Wizard = $Wizard
@onready var dummy: Dummy = $Dummy
@onready var input: MultiStrokeInput = $MultiStrokeInput
@onready var result_label: Label = $HUD/ResultLabel
@onready var detail_label: Label = $HUD/DetailLabel

var recognizer: QRecognizer
var _result_time := 0.0

func _ready() -> void:
	recognizer = QRecognizer.new(config)
	input.wait_time = config.multistroke_wait
	input.glyph_finished.connect(_on_glyph)
	input.glyph_cancelled.connect(func(reason): _show("", Color.WHITE, "취소: " + reason))
	$HUD/ResetButton.pressed.connect(dummy.reset_stats)
	result_label.text = ""
	detail_label.text = "아래 룬을 그려봐 (여러 획 가능, 손 떼고 %.1f초 뒤 발동)" % config.multistroke_wait
	if "--autoplay" in OS.get_cmdline_user_args():
		_autoplay()

func _process(delta: float) -> void:
	if _result_time > 0.0:
		_result_time -= delta
		result_label.modulate.a = clampf(_result_time, 0.0, 1.0)

func _on_glyph(strokes: Array) -> void:
	var r := recognizer.recognize(strokes, get_viewport_rect().size.y)
	var tier_name: String = RuneConfig.TIER_NAMES[r.tier]
	var detail := "1등 %s %.2f / 2등 %s %.2f · %d획 · %.1fms" % [r.best_name, r.score, r.second_name, r.second_score, strokes.size(), r.ms]
	if r.tier == "fail":
		input.flash_result(Color(0.6, 0.6, 0.6))
		_show(tier_name, Color(0.75, 0.75, 0.75), r.reason + "\n" + detail)
	elif r.element == Element.NONE:
		input.flash_result(Color(0.85, 0.8, 0.95))
		_show("%s · %s" % [r.name, tier_name], Color(0.85, 0.8, 0.95), "속성 없음 (인식 시험용)\n" + detail)
	else:
		var kind := wizard.apply_rune(r.element, r.tier)
		var c := Element.color_of(r.element)
		input.flash_result(c)
		var extra: String = {"refresh": "시간 갱신", "new": "부여", "replace": "교체"}[kind]
		extra += " %s %d초" % [Element.name_of(r.element), int(config.duration_for(r.tier))]
		if r.tier == "perfect" and kind != "refresh":
			extra += " + 강화탄"
		_show("%s · %s" % [r.name, tier_name], c, extra + "\n" + detail)
	print("[q] ", r.best_name, " ", r.tier, " ", snappedf(r.score, 0.01), " 2nd ", r.second_name, " ", snappedf(r.second_score, 0.01), " ", r.reason, " ", snappedf(r.ms, 0.1), "ms")
	_log(r, strokes.size())

func _show(title: String, color: Color, detail: String) -> void:
	result_label.text = title
	result_label.modulate = color
	_result_time = 1.8
	detail_label.text = detail

func _log(r: Dictionary, stroke_count: int) -> void:
	var exists := FileAccess.file_exists(LOG_PATH)
	var f := FileAccess.open(LOG_PATH, FileAccess.READ_WRITE if exists else FileAccess.WRITE)
	if f == null:
		return
	if exists:
		f.seek_end()
	else:
		f.store_line("time,tier,best,score,second,second_score,reason,strokes,ms")
	f.store_line("%s,%s,%s,%.3f,%s,%.3f,%s,%d,%.1f" % [Time.get_datetime_string_from_system(), r.tier,
		r.best_name, r.score, r.second_name, r.second_score, r.reason, stroke_count, r.ms])

# ---- 룬 안내 (하단 9개) ----

func _draw() -> void:
	var font := ThemeDB.fallback_font
	var list := QRecognizer.runes()
	var x0 := 540.0 - guide_gap * (list.size() - 1) / 2.0
	for i in list.size():
		var r: Dictionary = list[i]
		var cx := x0 + i * guide_gap
		var origin := Vector2(cx - guide_size / 2, guide_y - guide_size / 2)
		var c := Element.color_of(r.element) if r.element != Element.NONE else Color(0.7, 0.68, 0.78)
		draw_rect(Rect2(origin - Vector2(12, 12), Vector2(guide_size + 24, guide_size + 24)), Color(1, 1, 1, 0.06))
		for s in r.strokes:
			var pts := PackedVector2Array()
			for p in s:
				pts.append(origin + p * guide_size)
			draw_polyline(pts, c, 5, true)
		draw_string(font, Vector2(cx - 56, guide_y + guide_size / 2 + 40), r.name, HORIZONTAL_ALIGNMENT_CENTER, 112, 22, c)

# ---- 자동 재생 ----

func _autoplay() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var by_id := {}
	for r in QRecognizer.runes():
		by_id[r.id] = r
	for id in ["kaunan", "isa", "thurisaz", "gebo", "algiz", "fehu"]:
		await get_tree().create_timer(1.6).timeout
		await _draw_glyph(by_id[id].strokes, rng)
	# 낙서
	await get_tree().create_timer(1.6).timeout
	var scrib := PackedVector2Array([Vector2(0.2, 0.3), Vector2(0.8, 0.5), Vector2(0.3, 0.9), Vector2(0.6, 0.1), Vector2(0.9, 0.8)])
	await _draw_glyph([scrib], rng)

func _draw_glyph(shape: Array, rng: RandomNumberGenerator) -> void:
	var size := 360.0
	var origin := Vector2(540, 1000) - Vector2(size, size) / 2.0
	for s in shape:
		var pts := PackedVector2Array()
		for i in range(s.size() - 1):
			var n := maxi(int(s[i].distance_to(s[i + 1]) * size / 14.0), 2)
			for k in n:
				pts.append(origin + s[i].lerp(s[i + 1], float(k) / n) * size + Vector2(rng.randf_range(-5, 5), rng.randf_range(-5, 5)))
		pts.append(origin + s[s.size() - 1] * size)
		input.begin_stroke(pts[0])
		for i in range(1, pts.size()):
			input.add_point(pts[i])
			if i % 3 == 0:
				await get_tree().process_frame
		input.end_stroke()
		await get_tree().create_timer(0.15).timeout
