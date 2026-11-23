extends SceneTree
## $Q 인식기 헤드리스 테스트: godot --headless -s res://tools/test_q.gd [-- --config=res://data/rune_config_q.tres]
## 룬마다 획 순서 섞기·방향 뒤집기·꼭짓점 왜곡·흔들림·크기·약간 기울임을 준 가짜 획으로
## 점수 분포, 판정 단계, 오인식(어떤 룬으로)을 찍고, 낙서 점수와 인식 시간을 본다.

func _init() -> void:
	var path := "res://data/rune_config_q.tres"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--config="):
			path = a.substr(9)
	var cfg: RuneConfig = load(path)
	var rec := QRecognizer.new(cfg)
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	var total_ms := 0.0
	var calls := 0
	for warp in [0.04, 0.08, 0.12]:
		print("--- 꼭짓점 왜곡 %.0f%% ---" % (warp * 100))
		for r in QRecognizer.runes():
			var counts := {"perfect": 0, "good": 0, "normal": 0, "weak": 0, "fail": 0}
			var wrong := {}
			var scores: Array = []
			for trial in 40:
				var strokes := _make(r.strokes, warp, rng)
				var res := rec.recognize(strokes, 1920.0)
				total_ms += res.ms
				calls += 1
				scores.append(res.score)
				if res.tier != "fail" and res.id != r.id:
					wrong[res.name] = wrong.get(res.name, 0) + 1
				elif res.tier == "fail" and res.best_name != r.name:
					wrong["(실패)" + res.best_name] = wrong.get("(실패)" + res.best_name, 0) + 1
				else:
					counts[res.tier] += 1
			scores.sort()
			print("%s: 완벽 %d 좋음 %d 보통 %d 미흡 %d 실패 %d | 점수 최저 %.2f 중앙 %.2f | 오인식 %s" % [
				r.name, counts.perfect, counts.good, counts.normal, counts.weak, counts.fail,
				scores[0], scores[scores.size() / 2], wrong])
	print("--- 낙서 ---")
	var sc: Array = []
	var passed := 0
	for i in 30:
		var strokes: Array = []
		for k in rng.randi_range(1, 3):
			var s := PackedVector2Array()
			var p := Vector2(rng.randf_range(400, 700), rng.randf_range(800, 1100))
			for j in 25:
				p += Vector2(rng.randf_range(-40, 40), rng.randf_range(-40, 40))
				s.append(p)
			strokes.append(s)
		var res := rec.recognize(strokes, 1920.0)
		sc.append(res.score)
		if res.tier != "fail":
			passed += 1
	sc.sort()
	print("scribble passed %d / 30" % passed)
	print("낙서 점수 최고 %.2f / 상위 10%% %.2f / 중앙 %.2f" % [sc[sc.size() - 1], sc[int(sc.size() * 0.9)], sc[sc.size() / 2]])
	print("평균 인식 시간 %.2f ms" % (total_ms / calls))
	quit()

func _make(shape: Array, warp: float, rng: RandomNumberGenerator) -> Array:
	var size := rng.randf_range(300, 600)
	var rot := deg_to_rad(rng.randf_range(-8, 8))
	var center := Vector2(540, 1000)
	var out: Array = []
	for s in shape:
		var v: PackedVector2Array = s.duplicate()
		for i in v.size():
			v[i] += Vector2(rng.randf_range(-warp, warp), rng.randf_range(-warp, warp))
		if rng.randf() < 0.5:
			v.reverse()
		var pts := PackedVector2Array()
		for i in range(v.size() - 1):
			var n := maxi(int(v[i].distance_to(v[i + 1]) * size / 10.0), 2)
			for k in n:
				var p := (v[i].lerp(v[i + 1], float(k) / n) - Vector2(0.5, 0.5)) * size
				pts.append(center + p.rotated(rot) + Vector2(rng.randf_range(-6, 6), rng.randf_range(-6, 6)))
		pts.append(center + ((v[v.size() - 1] - Vector2(0.5, 0.5)) * size).rotated(rot))
		out.append(pts)
	out.shuffle()
	return out
