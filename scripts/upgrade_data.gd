class_name UpgradeData
extends Resource
## 강화 한 종류. 효과 동작은 id로 main.gd에서 처리하고, 수치는 여기서 조절.

@export var id: String = ""
@export var title: String = ""
@export var description: String = ""
@export var amount: float = 0.0
@export var amount_b: float = 0.0
@export var max_stacks: int = 1
