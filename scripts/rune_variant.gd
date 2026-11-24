class_name RuneVariant
extends Resource
## 변형 룬: 같은 속성(모양 그대로)에 장착하는 전술 차이. data/variants/*.tres
## 지금은 불 변형만. 봇 검증용으로 `-- --fire-variant=<id>`로 고른다 (장착 화면은 나중).

@export var id: String = ""
@export var title: String = ""
@export var element: int = Element.FIRE
@export_multiline var description: String = ""

@export_group("화상 수치")
@export var burn_dps_mult: float = 1.0
@export var burn_duration_mult: float = 1.0

@export_group("폭염")
## 불 강화탄이 맞히면 이 반경 안 다른 적에게 화상 (원래 맞은 적 제외). 0이면 없음.
@export var empowered_burn_radius: float = 0.0

@export_group("역화")
## 불 칸이 다른 속성으로 교체되어 나갈 때(실제 칸 교체만, 갱신·빈 칸은 아님) 다음 발사 탄 1발에 추가 피해를 예약.
## "none" 없음 / "remaining" 계수 x 남은 시간 (대조군) / "min" 계수 x min(마지막 갱신 뒤 경과, 남은 시간)
## / "charge" 계수 x 마지막 예약 뒤 쌓인 화상 피해량
@export_enum("none", "remaining", "min", "charge") var backfire_formula: String = "none"
@export var backfire_coef: float = 0.0
## 마지막 불 시전 뒤 불 탄이 한 번도 맞지 않았으면 보상 없음
@export var backfire_require_hit: bool = false

## duration·left: 교체 직전 불 칸의 지속 시간·남은 시간. charge: 쌓인 화상 피해. hits: 마지막 불 시전 뒤 불 탄 명중 수
func backfire_reward(duration: float, left: float, charge: float, hits: int) -> float:
	if backfire_require_hit and hits <= 0:
		return 0.0
	left = maxf(left, 0.0)
	match backfire_formula:
		"remaining":
			return backfire_coef * left
		"min":
			return backfire_coef * minf(maxf(duration - left, 0.0), left)
		"charge":
			return backfire_coef * maxf(charge, 0.0)
	return 0.0

static func load_id(vid: String) -> RuneVariant:
	var path := "res://data/variants/fire_%s.tres" % vid
	if not ResourceLoader.exists(path):
		push_warning("변형 룬 없음: " + path)
		return null
	return load(path) as RuneVariant
