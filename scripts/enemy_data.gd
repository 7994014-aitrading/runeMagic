class_name EnemyData
extends Resource
## 적 종류별 수치. data/enemy_*.tres

@export var display_name: String = ""
@export var hp: float = 30.0
@export var speed: float = 100.0  # px/초
@export var radius: float = 24.0
@export var color: Color = Color.WHITE
@export var castle_damage: int = 1  # 성에 닿으면 깎는 체력
## 그림 (scripts/art.gd ENEMY_SHEETS 키, 비면 도형) · 그릴 배율 (시트 한 칸 크기 기준)
@export var sprite: String = ""
@export var sprite_scale: float = 1.0
