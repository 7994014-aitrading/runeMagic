class_name QRecognizer
extends RefCounted
## $Q 인식기 (Vatavu, Anthony, Wobbrock 2018): $P의 빠른 버전. 여러 획, 획 순서·방향 무관, 회전은 구분.
## 획들을 점 구름(N개)으로 만들고, 견본 점 구름과 짝지은 거리 합이 가장 작은 룬을 고른다.
## 속도: 하한(LUT)으로 가망 없는 시작점을 건너뛰고, 계산 중 현재 최고보다 나빠지면 중단한다.

const N := 32
const MAX_INT := 1024
const LUT_SIZE := 64
const LUT_SCALE := MAX_INT / LUT_SIZE

var config: RuneConfig
var templates: Array = []  # [{id, name, element, cloud}]

func _init(cfg: RuneConfig) -> void:
	config = cfg
	for r in runes():
		templates.append({"id": r.id, "name": r.name, "element": r.element, "cloud": _normalize(_densify(r.strokes))})

## 시험용 엘더 푸사르크 룬 9종 (0~1 좌표, y 아래로). element가 NONE이면 인식만 하고 속성 없음.
static func runes() -> Array:
	return [
		{"id": "kaunan", "name": "카우나즈", "element": Element.FIRE, "strokes": [
			PackedVector2Array([Vector2(0.7, 0), Vector2(0.3, 0.5), Vector2(0.7, 1)])]},
		{"id": "isa", "name": "이사", "element": Element.ICE, "strokes": [
			PackedVector2Array([Vector2(0.5, 0), Vector2(0.5, 1)])]},
		{"id": "thurisaz", "name": "투리사즈", "element": Element.LIGHTNING, "strokes": [
			PackedVector2Array([Vector2(0.3, 0), Vector2(0.3, 1)]),
			PackedVector2Array([Vector2(0.3, 0.25), Vector2(0.72, 0.5), Vector2(0.3, 0.75)])]},
		{"id": "fehu", "name": "페후", "element": Element.NONE, "strokes": [
			PackedVector2Array([Vector2(0.3, 0), Vector2(0.3, 1)]),
			PackedVector2Array([Vector2(0.3, 0.35), Vector2(0.75, 0.05)]),
			PackedVector2Array([Vector2(0.3, 0.62), Vector2(0.75, 0.32)])]},
		{"id": "uruz", "name": "우루즈", "element": Element.NONE, "strokes": [
			PackedVector2Array([Vector2(0.25, 1), Vector2(0.25, 0), Vector2(0.75, 0.3), Vector2(0.75, 1)])]},
		{"id": "raido", "name": "라이도", "element": Element.NONE, "strokes": [
			PackedVector2Array([Vector2(0.3, 0), Vector2(0.3, 1)]),
			PackedVector2Array([Vector2(0.3, 0), Vector2(0.72, 0.25), Vector2(0.3, 0.5), Vector2(0.72, 1)])]},
		{"id": "gebo", "name": "게보", "element": Element.NONE, "strokes": [
			PackedVector2Array([Vector2(0.15, 0), Vector2(0.85, 1)]),
			PackedVector2Array([Vector2(0.85, 0), Vector2(0.15, 1)])]},
		{"id": "algiz", "name": "알기즈", "element": Element.NONE, "strokes": [
			PackedVector2Array([Vector2(0.5, 0), Vector2(0.5, 1)]),
			PackedVector2Array([Vector2(0.5, 0.45), Vector2(0.15, 0)]),
			PackedVector2Array([Vector2(0.5, 0.45), Vector2(0.85, 0)])]},
		{"id": "tiwaz", "name": "티와즈", "element": Element.NONE, "strokes": [
			PackedVector2Array([Vector2(0.5, 0), Vector2(0.5, 1)]),
			PackedVector2Array([Vector2(0.15, 0.35), Vector2(0.5, 0), Vector2(0.85, 0.35)])]},
	]

## strokes: Array[PackedVector2Array]
## 결과: {id, name, element, tier, score, second_name, second_score, reason, ms}
func recognize(strokes: Array, screen_height: float) -> Dictionary:
	var t0 := Time.get_ticks_usec()
	var res := {"id": "", "name": "", "element": Element.NONE, "tier": "fail", "score": 0.0,
		"best_name": "", "second_name": "", "second_score": 0.0, "reason": "", "ms": 0.0}
	var total_pts := 0
	var length := 0.0
	for s in strokes:
		total_pts += s.size()
		for i in range(1, s.size()):
			length += s[i - 1].distance_to(s[i])
	if strokes.size() > config.max_strokes:
		res.reason = "획이 너무 많음"
		return res
	if total_pts < config.min_points:
		res.reason = "점이 너무 적음"
		return res
	if length < screen_height * config.min_length_ratio:
		res.reason = "획이 너무 짧음"
		return res
	var cand := _normalize(_from_strokes(strokes))
	var best := -1
	var best_d := INF
	for i in templates.size():
		var d := _cloud_match(cand, templates[i].cloud, best_d)
		if d < best_d:
			best_d = d
			best = i
	# 2등: 1등 룬을 뺀 나머지에서 다시 정확한 최소값
	var second := -1
	var second_d := INF
	for i in templates.size():
		if templates[i].id == templates[best].id:
			continue
		var d := _cloud_match(cand, templates[i].cloud, second_d)
		if d < second_d:
			second_d = d
			second = i
	res.best_name = templates[best].name
	res.score = _to_score(best_d)
	if second >= 0:
		res.second_name = templates[second].name
		res.second_score = _to_score(second_d)
	var tier := config.tier_of(res.score)
	if tier == "fail":
		res.reason = "모양이 안 맞음"
	elif res.score - res.second_score < config.min_margin:
		res.reason = "헷갈림"
	else:
		res.tier = tier
		res.id = templates[best].id
		res.name = templates[best].name
		res.element = templates[best].element
	res.ms = (Time.get_ticks_usec() - t0) / 1000.0
	return res

## 가중 평균 제곱거리 → 0~1 점수 (평균 거리 0.5 이상이면 0)
func _to_score(d: float) -> float:
	var w := N * (N + 1) / 2.0
	return maxf(0.0, 1.0 - sqrt(d / w) / 0.5)

# ---- 점 구름 만들기 ----

func _from_strokes(strokes: Array) -> Dictionary:
	var p := PackedVector2Array()
	var sid := PackedInt32Array()
	for k in strokes.size():
		for v in strokes[k]:
			p.append(v)
			sid.append(k)
	return {"p": p, "sid": sid}

func _densify(strokes: Array) -> Dictionary:
	var p := PackedVector2Array()
	var sid := PackedInt32Array()
	for k in strokes.size():
		var s: PackedVector2Array = strokes[k]
		for i in range(s.size() - 1):
			for j in 16:
				p.append(s[i].lerp(s[i + 1], j / 16.0) * 100.0)
				sid.append(k)
		p.append(s[s.size() - 1] * 100.0)
		sid.append(k)
	return {"p": p, "sid": sid}

func _normalize(raw: Dictionary) -> Dictionary:
	var c := _resample(raw.p, raw.sid)
	var p: PackedVector2Array = c.p
	# 비율 유지 크기 맞춤
	var mn := p[0]
	var mx := p[0]
	for v in p:
		mn = mn.min(v)
		mx = mx.max(v)
	var size := maxf(maxf(mx.x - mn.x, mx.y - mn.y), 0.0001)
	var cen := Vector2.ZERO
	for i in p.size():
		p[i] = (p[i] - mn) / size
		cen += p[i]
	cen /= p.size()
	var ix := PackedInt32Array()
	var iy := PackedInt32Array()
	for i in p.size():
		p[i] -= cen
		ix.append(clampi(roundi((p[i].x + 1.0) / 2.0 * (MAX_INT - 1)), 0, MAX_INT - 1))
		iy.append(clampi(roundi((p[i].y + 1.0) / 2.0 * (MAX_INT - 1)), 0, MAX_INT - 1))
	var lut := PackedInt32Array()
	lut.resize(LUT_SIZE * LUT_SIZE)
	for x in LUT_SIZE:
		for y in LUT_SIZE:
			var u := -1
			var b := INF
			for i in p.size():
				var row := roundi(ix[i] / float(LUT_SCALE))
				var col := roundi(iy[i] / float(LUT_SCALE))
				var d := float((row - x) * (row - x) + (col - y) * (col - y))
				if d < b:
					b = d
					u = i
			lut[x * LUT_SIZE + y] = u
	return {"p": p, "ix": ix, "iy": iy, "lut": lut}

## 여러 획을 합쳐 N개 점으로 (획 사이 빈 구간은 길이에 넣지 않음)
func _resample(pts: PackedVector2Array, sid: PackedInt32Array) -> Dictionary:
	var length := 0.0
	for i in range(1, pts.size()):
		if sid[i] == sid[i - 1]:
			length += pts[i - 1].distance_to(pts[i])
	var interval := length / (N - 1)
	var src := pts.duplicate()
	var ids := sid.duplicate()
	var out := PackedVector2Array([src[0]])
	var dist := 0.0
	var i := 1
	while i < src.size():
		if ids[i] == ids[i - 1]:
			var d := src[i - 1].distance_to(src[i])
			if dist + d >= interval and d > 0.0:
				var q := src[i - 1] + (interval - dist) / d * (src[i] - src[i - 1])
				out.append(q)
				src.insert(i, q)
				ids.insert(i, ids[i])
				dist = 0.0
			else:
				dist += d
		i += 1
	while out.size() < N:
		out.append(src[src.size() - 1])
	if out.size() > N:
		out.resize(N)
	return {"p": out}

# ---- 비교 ($Q) ----

func _cloud_match(a: Dictionary, b: Dictionary, min_so_far: float) -> float:
	var step := int(floor(sqrt(N)))
	var lb1 := _lower_bound(a, b, step)
	var lb2 := _lower_bound(b, a, step)
	var i := 0
	var j := 0
	while i < N:
		if lb1[j] < min_so_far:
			min_so_far = minf(min_so_far, _cloud_distance(a.p, b.p, i, min_so_far))
		if lb2[j] < min_so_far:
			min_so_far = minf(min_so_far, _cloud_distance(b.p, a.p, i, min_so_far))
		i += step
		j += 1
	return min_so_far

func _cloud_distance(p1: PackedVector2Array, p2: PackedVector2Array, start: int, min_so_far: float) -> float:
	var unmatched := range(N)
	var i := start
	var weight := N
	var total := 0.0
	while true:
		var u := -1
		var best := INF
		for k in unmatched.size():
			var d := p1[i].distance_squared_to(p2[unmatched[k]])
			if d < best:
				best = d
				u = k
		unmatched.remove_at(u)
		total += weight * best
		if total >= min_so_far:
			return total
		weight -= 1
		i = (i + 1) % N
		if i == start:
			break
	return total

func _lower_bound(a: Dictionary, b: Dictionary, step: int) -> PackedFloat32Array:
	var lb := PackedFloat32Array()
	lb.resize(N / step + 1)
	var sat := PackedFloat32Array()
	sat.resize(N)
	lb[0] = 0.0
	for i in N:
		var x: int = a.ix[i] / LUT_SCALE
		var y: int = a.iy[i] / LUT_SCALE
		var idx: int = b.lut[x * LUT_SIZE + y]
		var d: float = a.p[i].distance_squared_to(b.p[idx])
		sat[i] = d if i == 0 else sat[i - 1] + d
		lb[0] += (N - i) * d
	var i2 := step
	var j := 1
	while i2 < N:
		lb[j] = lb[0] + i2 * sat[N - 1] - N * sat[i2 - 1]
		i2 += step
		j += 1
	return lb
