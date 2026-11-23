class_name PermUpgradeData
extends UpgradeData
## 영구 강화 한 종류 (판 밖, 마력석으로 레벨업). 효과는 id로 main.gd에서 처리.
## amount = 레벨당 효과, max_stacks = 최대 레벨. 비용 = cost_base + cost_step * 현재 레벨.

@export var cost_base: int = 40
@export var cost_step: int = 30
@export var unit: String = ""  # 효과 표시 단위 ("%", "초" 등)

func cost_at(level: int) -> int:
	return cost_base + cost_step * level
