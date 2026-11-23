class_name Art
extends RefCounted
## 그림·이펙트 불러오기. 에셋 파일이 없으면(assets/third_party는 git에 없음) null을 돌려주고,
## 그리는 쪽은 예전 도형 그림으로 대신한다. 출처는 assets/CREDITS.md.

const ENEMY_DIR := "res://assets/third_party/gegx/enemies/"
const WIZARD_DIR := "res://assets/third_party/gegx/wizard/"
const FX_DIR := "res://assets/third_party/miraforge/"

## 적 그림: EnemyData.sprite 키 → [파일, 열 수, 행 수]. 행 순서는 아래·왼·오른·위 (아래 = 정면).
const ENEMY_SHEETS := {
	"imp": ["imp_walk.png", 13, 4],
	"acolyte": ["acolyte_walk.png", 13, 4],
	"stormharpy": ["stormharpy_walk.png", 6, 4],
	"staticweaver": ["staticweaver_walk.png", 6, 4],
}

## 이펙트 시트 (64x64 한 줄): 이름 → [파일, 프레임 수, 반복 여부]
const FX := {
	"fireball": ["fireball_64x64_sheet.png", 8, true],
	"fire_burst": ["fire_burst_64x64_sheet.png", 10, false],
	"ice_shard": ["ice_shard_64x64_sheet.png", 8, true],
	"ice_shatter": ["ice_shatter_64x64_sheet.png", 10, false],
	"frost_nova": ["frost_nova_64x64_sheet.png", 12, true],
	"spark_orb": ["spark_orb_64x64_sheet.png", 8, true],
	"lightning_strike": ["lightning_strike_64x64_sheet.png", 10, false],
	"storm_ring": ["storm_ring_64x64_sheet.png", 12, true],
	"arcane_missile": ["arcane_missile_64x64_sheet.png", 8, true],
	"rune_ring": ["rune_ring_64x64_sheet.png", 12, true],
}
const FX_FPS := 12.0

static var _cache := {}

static func _tex(path: String) -> Texture2D:
	if _cache.has(path):
		return _cache[path]
	var t: Texture2D = load(path) if ResourceLoader.exists(path) else null
	_cache[path] = t
	return t

## 적 시트: {tex, cols, rows, fw, fh} 또는 null
static func enemy_sheet(key: String):
	if key == "" or not ENEMY_SHEETS.has(key):
		return null
	var s: Array = ENEMY_SHEETS[key]
	var t := _tex(ENEMY_DIR + s[0])
	if t == null:
		return null
	return {"tex": t, "cols": s[1], "rows": s[2], "fw": t.get_width() / s[1], "fh": t.get_height() / s[2]}

## 마법사 프레임 (뒷모습 대기 12장). 없으면 빈 배열.
static func wizard_frames(dir := "north") -> Array:
	var key := "wizard_" + dir
	if _cache.has(key):
		return _cache[key]
	var out := []
	for i in 32:
		var t := _tex(WIZARD_DIR + "idle_%s/%02d.png" % [dir, i])
		if t == null:
			break
		out.append(t)
	_cache[key] = out
	return out

static func fx_sheet(name: String) -> Texture2D:
	if not FX.has(name):
		return null
	return _tex(FX_DIR + FX[name][0])

static func fx_frames(name: String) -> int:
	return FX[name][1] if FX.has(name) else 1

static func fx_loops(name: String) -> bool:
	return FX[name][2] if FX.has(name) else false

## 속성 → 탄 이펙트
static func projectile_fx(element: int) -> String:
	match element:
		Element.FIRE:
			return "fireball"
		Element.ICE:
			return "ice_shard"
		Element.LIGHTNING:
			return "spark_orb"
	return "arcane_missile"

## 속성 → 맞았을 때 이펙트
static func impact_fx(element: int) -> String:
	match element:
		Element.FIRE:
			return "fire_burst"
		Element.ICE:
			return "ice_shatter"
		Element.LIGHTNING:
			return "lightning_strike"
	return ""

## 시트의 한 프레임을 center 기준으로 그린다 (size = 그릴 한 변 길이)
static func draw_fx_frame(ci: CanvasItem, name: String, frame: int, center: Vector2, size: float, modulate := Color.WHITE) -> void:
	var t := fx_sheet(name)
	if t == null:
		return
	var n := fx_frames(name)
	var fw := t.get_width() / n
	var src := Rect2((frame % n) * fw, 0, fw, t.get_height())
	ci.draw_texture_rect_region(t, Rect2(center - Vector2(size, size) / 2.0, Vector2(size, size)), src, modulate)
