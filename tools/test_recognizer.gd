extends SceneTree
## 인식기 헤드리스 테스트: godot --headless -s res://tools/test_recognizer.gd
## 룬마다 흔들림·크기·회전·방향을 바꾼 가짜 획으로 판정 비율을 찍고, 거부 사례를 확인한다.

func _init() -> void:
	var cfg: RuneConfig = load("res://data/rune_config.tres")
	var rec := RuneRecognizer.new(cfg)
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	var shapes := RuneRecognizer.shapes()
	for warp in [0.0, 0.08, 0.15, 0.25]:
		var jitter := 8.0
		print("--- 꼭짓점 왜곡 %.0f%% (흔들림 8px) ---" % (warp * 100))
		for e in shapes.keys():
			var counts := {"perfect": 0, "good": 0, "normal": 0, "weak": 0, "fail": 0, "wrong": 0}
			for trial in 50:
				var shape: PackedVector2Array = shapes[e].duplicate()
				if trial % 2 == 1:
					shape.reverse()
				for v in shape.size():
					shape[v] += Vector2(rng.randf_range(-warp, warp), rng.randf_range(-warp, warp))
				var size := rng.randf_range(250, 600)
				var rot := deg_to_rad(rng.randf_range(-20, 20))
				var pts := _make(shape, size, jitter, rot, rng)
				var r := rec.recognize(pts, 1920.0)
				if r.tier != "fail" and r.element != e:
					counts.wrong += 1
				else:
					counts[r.tier] += 1
			print("%s: perfect %d / good %d / normal %d / weak %d / fail %d / wrong %d" % [Element.name_of(e), counts.perfect, counts.good, counts.normal, counts.weak, counts.fail, counts.wrong])
	print("--- 거부 ---")
	var cases := {
		"짧은 터치": PackedVector2Array([Vector2(500, 500), Vector2(503, 501), Vector2(506, 503)]),
		"직선": _make(PackedVector2Array([Vector2(0, 0), Vector2(1, 0.05)]), 500, 3, 0, rng),
		"작은 ∧": _make(shapes[Element.FIRE], 60, 1, 0, rng),
	}
	for i in 10:
		cases["낙서%d" % i] = _scribble(rng)
	for k in cases.keys():
		var r := rec.recognize(cases[k], 1920.0)
		print("%s → %s %s (1등 %s %.2f / 2등 %s %.2f)" % [k, r.tier, r.reason, Element.name_of(r.get("best_element", 0)), r.score, Element.name_of(r.second_element), r.second_score])
	quit()

func _make(shape: PackedVector2Array, size: float, jitter: float, rot: float, rng: RandomNumberGenerator) -> PackedVector2Array:
	var out := PackedVector2Array()
	var center := Vector2(540, 1000)
	for i in range(shape.size() - 1):
		var n := maxi(int(shape[i].distance_to(shape[i + 1]) * size / 10.0), 2)
		for k in n:
			var p := (shape[i].lerp(shape[i + 1], float(k) / n) - Vector2(0.5, 0.5)) * size
			out.append(center + p.rotated(rot) + Vector2(rng.randf_range(-jitter, jitter), rng.randf_range(-jitter, jitter)))
	out.append(center + ((shape[shape.size() - 1] - Vector2(0.5, 0.5)) * size).rotated(rot))
	return out

func _scribble(rng: RandomNumberGenerator) -> PackedVector2Array:
	var out := PackedVector2Array()
	var p := Vector2(540, 1000)
	for i in 80:
		p += Vector2(rng.randf_range(-40, 40), rng.randf_range(-40, 40))
		out.append(p)
	return out
