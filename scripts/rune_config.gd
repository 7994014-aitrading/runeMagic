class_name RuneConfig
extends Resource
## 룬 인식·속성 칸·기본 공격 밸런스 값. data/rune_config.tres 에서 수정.

const TIERS := ["fail", "weak", "normal", "good", "perfect"]
const TIER_NAMES := {"fail": "실패", "weak": "미흡", "normal": "보통", "good": "좋음", "perfect": "완벽"}

@export_group("판정")
## 단계 경계 점수 4개: 미흡·보통·좋음·완벽이 시작되는 점수 (이보다 낮으면 실패)
@export var tier_thresholds: PackedFloat32Array = PackedFloat32Array([0.80, 0.84, 0.87, 0.90])
## 단계별 속성 지속 시간: 미흡·보통·좋음·완벽
@export var tier_durations: PackedFloat32Array = PackedFloat32Array([5.0, 8.0, 10.0, 12.0])
## 1등 속성과 2등 속성 점수 차이가 이보다 작으면 헷갈림으로 실패
@export_range(0.0, 0.5, 0.01) var min_margin: float = 0.04
## 획 길이 하한 (화면 높이 대비 비율)
@export_range(0.0, 0.5, 0.01) var min_length_ratio: float = 0.08
## 획 점 개수 하한
@export var min_points: int = 10
## 시작점-끝점 거리 / 획 길이가 이 값 이상이면 직선으로 보고 실패
@export_range(0.5, 1.0, 0.01) var straight_ratio: float = 0.95

@export_group("속성 칸")
@export var slot_count: int = 1

@export_group("기본 공격")
@export var fire_interval: float = 0.45
@export var projectile_speed: float = 1600.0
@export var base_damage: float = 10.0
@export var empowered_multiplier: float = 2.0
@export var pool_size: int = 32

@export_group("시험용")
## 그리는 동안 게임 속도를 늦출지 (기본 꺼짐)
@export var slow_while_drawing: bool = false
@export_range(0.1, 1.0, 0.05) var slow_scale: float = 0.5

## 점수 → 단계 키
func tier_of(score: float) -> String:
	var level := 0
	for t in tier_thresholds:
		if score >= t:
			level += 1
	return TIERS[level]

func duration_for(tier: String) -> float:
	var idx := TIERS.find(tier) - 1
	if idx < 0:
		return 0.0
	return tier_durations[idx]

@export_group("여러 획 ($Q)")
## 마지막 획을 뗀 뒤 이 시간 동안 새 획이 없으면 발동
@export var multistroke_wait: float = 0.4
@export var max_strokes: int = 5
