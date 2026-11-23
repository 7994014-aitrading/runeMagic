class_name RuneRecognizer
extends RefCounted
## $1 Unistroke 인식기 (Wobbrock 2007) + 거부 기준 + 5단계 판정.
## 견본은 코드로 생성한다. 각 룬은 정방향·역방향 두 견본을 가진다.

const N := 64
const SQUARE := 250.0
const ANGLE_RANGE := deg_to_rad(45.0)
const ANGLE_PRECISION := deg_to_rad(2.0)
const PHI := 0.6180339887

var config: RuneConfig
var templates: Array = []  # [{element, points}]

func _init(cfg: RuneConfig) -> void:
	config = cfg
	var sh := shapes()
	for e in sh.keys():
		var raw: PackedVector2Array = sh[e]
		_add_template(e, raw)
		var rev := raw.duplicate()
		rev.reverse()
		_add_template(e, rev)

## 룬 원본 모양 (0~1 좌표, y 아래로). 화면 안내 그림에도 쓴다.
static func shapes() -> Dictionary:
	var circle := PackedVector2Array()
	for i in range(33):
		var a := -PI / 2.0 + TAU * i / 32.0
		circle.append(Vector2(0.5 + 0.5 * cos(a), 0.5 + 0.5 * sin(a)))
	return {
		Element.FIRE: PackedVector2Array([Vector2(0, 1), Vector2(0.5, 0), Vector2(1, 1)]),
		Element.ICE: circle,
		Element.LIGHTNING: PackedVector2Array([Vector2(0, 0), Vector2(1, 0), Vector2(0, 1), Vector2(1, 1)]),
	}

func _add_template(e: int, raw: PackedVector2Array) -> void:
	var pts := _densify(raw)
	templates.append({"element": e, "points": _normalize(pts)})

## 결과: {element, tier, score, best_element, second_element, second_score, reason}
## tier: fail / weak / normal / good / perfect
func recognize(stroke: PackedVector2Array, screen_height: float) -> Dictionary:
	var res := {"element": Element.NONE, "tier": "fail", "score": 0.0, "best_element": Element.NONE,
		"second_element": Element.NONE, "second_score": 0.0, "reason": ""}
	if stroke.size() < config.min_points:
		res.reason = "점이 너무 적음"
		return res
	var length := _path_length(stroke)
	if length < screen_height * config.min_length_ratio:
		res.reason = "획이 너무 짧음"
		return res
	if stroke[0].distance_to(stroke[stroke.size() - 1]) / length >= config.straight_ratio:
		res.reason = "직선"
		return res

	var cand := _normalize(stroke)
	var best_by_element := {}
	for t in templates:
		var d := _distance_at_best_angle(cand, t.points)
		var score := 1.0 - d / (0.5 * sqrt(2.0 * SQUARE * SQUARE))
		if score > best_by_element.get(t.element, -INF):
			best_by_element[t.element] = score
	var ranked: Array = best_by_element.keys()
	ranked.sort_custom(func(a, b): return best_by_element[a] > best_by_element[b])
	res.best_element = ranked[0]
	res.score = best_by_element[ranked[0]]
	if ranked.size() > 1:
		res.second_element = ranked[1]
		res.second_score = best_by_element[ranked[1]]

	var tier := config.tier_of(res.score)
	if tier == "fail":
		res.reason = "모양이 안 맞음"
	elif res.score - res.second_score < config.min_margin:
		res.reason = "헷갈림"
	else:
		res.tier = tier
		res.element = res.best_element
	return res

# ---- $1 단계 ----

func _normalize(pts: PackedVector2Array) -> PackedVector2Array:
	var p := _resample(pts, N)
	p = _rotate_by(p, -_indicative_angle(p))
	p = _scale_to_square(p)
	return _translate_to_origin(p)

func _densify(raw: PackedVector2Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i in range(raw.size() - 1):
		for k in range(16):
			out.append(raw[i].lerp(raw[i + 1], k / 16.0) * 100.0)
	out.append(raw[raw.size() - 1] * 100.0)
	return out

func _resample(pts: PackedVector2Array, n: int) -> PackedVector2Array:
	var interval := _path_length(pts) / (n - 1)
	var dist := 0.0
	var src := pts.duplicate()
	var out := PackedVector2Array([src[0]])
	var i := 1
	while i < src.size():
		var d := src[i - 1].distance_to(src[i])
		if dist + d >= interval and d > 0.0:
			var q := src[i - 1] + (interval - dist) / d * (src[i] - src[i - 1])
			out.append(q)
			src.insert(i, q)
			dist = 0.0
		else:
			dist += d
		i += 1
	while out.size() < n:
		out.append(src[src.size() - 1])
	if out.size() > n:
		out.resize(n)
	return out

func _centroid(pts: PackedVector2Array) -> Vector2:
	var c := Vector2.ZERO
	for p in pts:
		c += p
	return c / pts.size()

func _indicative_angle(pts: PackedVector2Array) -> float:
	var c := _centroid(pts)
	return atan2(c.y - pts[0].y, c.x - pts[0].x)

func _rotate_by(pts: PackedVector2Array, angle: float) -> PackedVector2Array:
	var c := _centroid(pts)
	var out := PackedVector2Array()
	for p in pts:
		out.append((p - c).rotated(angle) + c)
	return out

func _scale_to_square(pts: PackedVector2Array) -> PackedVector2Array:
	var r := Rect2(pts[0], Vector2.ZERO)
	for p in pts:
		r = r.expand(p)
	var w := maxf(r.size.x, 1.0)
	var h := maxf(r.size.y, 1.0)
	var out := PackedVector2Array()
	for p in pts:
		out.append(Vector2(p.x * SQUARE / w, p.y * SQUARE / h))
	return out

func _translate_to_origin(pts: PackedVector2Array) -> PackedVector2Array:
	var c := _centroid(pts)
	var out := PackedVector2Array()
	for p in pts:
		out.append(p - c)
	return out

func _distance_at_best_angle(pts: PackedVector2Array, tmpl: PackedVector2Array) -> float:
	var a := -ANGLE_RANGE
	var b := ANGLE_RANGE
	var x1 := PHI * a + (1.0 - PHI) * b
	var f1 := _distance_at_angle(pts, tmpl, x1)
	var x2 := (1.0 - PHI) * a + PHI * b
	var f2 := _distance_at_angle(pts, tmpl, x2)
	while absf(b - a) > ANGLE_PRECISION:
		if f1 < f2:
			b = x2
			x2 = x1
			f2 = f1
			x1 = PHI * a + (1.0 - PHI) * b
			f1 = _distance_at_angle(pts, tmpl, x1)
		else:
			a = x1
			x1 = x2
			f1 = f2
			x2 = (1.0 - PHI) * a + PHI * b
			f2 = _distance_at_angle(pts, tmpl, x2)
	return minf(f1, f2)

func _distance_at_angle(pts: PackedVector2Array, tmpl: PackedVector2Array, angle: float) -> float:
	var r := _rotate_by(pts, angle)
	var d := 0.0
	for i in range(r.size()):
		d += r[i].distance_to(tmpl[i])
	return d / r.size()

func _path_length(pts: PackedVector2Array) -> float:
	var d := 0.0
	for i in range(1, pts.size()):
		d += pts[i - 1].distance_to(pts[i])
	return d
