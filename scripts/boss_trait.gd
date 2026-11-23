class_name BossTrait
extends Resource
## 보스 특성 하나. 동작은 id로 Enemy/Battle에서 한 번만 구현, 수치는 여기서.
## 필드 의미는 특성마다 다르다 (각 .tres 항목 주석 참고).

@export var id: String = ""  # shield / regen / summon / charge
@export var title: String = ""
@export var icon_text: String = ""  # 보스 위 아이콘 한 글자
@export var category: String = "defense"  # defense / action (종류별 최대 1개)
@export var amount: float = 0.0  # shield: 다른 속성 피해 배율 / regen: 초당 최대 체력 비율
@export var interval: float = 0.0  # summon·charge: 주기(초)
@export var duration: float = 0.0  # shield: 파괴 지속 / charge: 돌진 지속
@export var warn_time: float = 0.0  # charge: 예고 시간
@export var count: int = 0  # shield: 깨는 데 필요한 반응 수 / summon: 한 번에 소환 수
@export var max_count: int = 0  # summon: 동시 최대 졸개 수
@export var multiplier: float = 1.0  # shield: 파괴 중 피해 배율 / charge: 돌진 속도 배율
