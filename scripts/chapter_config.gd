class_name ChapterConfig
extends Resource
## 챕터(스테이지 묶음) 수치. data/chapter1.tres
## 스테이지 번호 s(1부터)에 따라 적 체력·웨이브 예산·보스 체력이 오른다. 속도는 오르지 않는다.

@export var title: String = "챕터 1"
@export var stage_count: int = 10
@export var waves_per_stage: int = 10

@export_group("난이도")
## 일반 적 체력 배율 = enemy_hp_start + enemy_hp_growth * (s-1)
@export var enemy_hp_start: float = 0.85
@export var enemy_hp_growth: float = 0.05
## 웨이브 예산 배율 = budget_start + budget_growth * (s-1)
@export var budget_start: float = 0.75
@export var budget_growth: float = 0.04
## 보스 체력 배율 = boss_hp_start + boss_hp_growth * (s-1)
@export var boss_hp_start: float = 0.8
@export var boss_hp_growth: float = 0.12
## 스테이지별 보스 특성 수 (1-1은 0: 튜토리얼)
@export var boss_trait_counts: PackedInt32Array = PackedInt32Array([0, 1, 1, 1, 1, 1, 1, 1, 1, 2])

@export_group("룬 해금")
## 이 스테이지에 처음 들어갈 수 있게 되면 해금 (불은 처음부터)
@export var ice_unlock_stage: int = 2
@export var lightning_unlock_stage: int = 3

@export_group("보상 (마력석)")
@export var clear_reward_base: int = 30
@export var clear_reward_per_stage: int = 10
@export var first_clear_bonus: int = 50
@export var loss_reward_per_wave: int = 3

@export_group("별")
## 클리어 = 별 1, 성 체력 비율이 [0] 이상이면 별 2, [1] 이상이면 별 3
@export var star_thresholds: PackedFloat32Array = PackedFloat32Array([0.5, 0.8])

func enemy_hp_mult(s: int) -> float:
	return enemy_hp_start + enemy_hp_growth * (s - 1)

func budget_mult(s: int) -> float:
	return budget_start + budget_growth * (s - 1)

func boss_hp_mult(s: int) -> float:
	return boss_hp_start + boss_hp_growth * (s - 1)

func boss_traits(s: int) -> int:
	return boss_trait_counts[clampi(s - 1, 0, boss_trait_counts.size() - 1)]

func clear_reward(s: int) -> int:
	return clear_reward_base + clear_reward_per_stage * (s - 1)

func stars_for(castle_ratio: float) -> int:
	var n := 1
	for t in star_thresholds:
		if castle_ratio >= t:
			n += 1
	return n

## 스테이지 s까지 열렸을 때 쓸 수 있는 속성
func runes_at(max_open_stage: int) -> Array:
	var out := [Element.FIRE]
	if max_open_stage >= ice_unlock_stage:
		out.append(Element.ICE)
	if max_open_stage >= lightning_unlock_stage:
		out.append(Element.LIGHTNING)
	return out

## 스테이지마다 고정 시드 (매번 같은 배치·같은 보스 특성)
func stage_seed(s: int) -> int:
	return 1000 + s * 37

func stage_name(s: int) -> String:
	return "1-%d" % s
