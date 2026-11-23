class_name CombatConfig
extends Resource
## 상태·반응·전투·웨이브 수치. data/combat_config.tres

@export_group("화상")
@export var burn_dps: float = 10.0
@export var burn_duration: float = 3.0
@export var burn_tick: float = 0.5

@export_group("감속")
@export_range(0.0, 1.0, 0.05) var slow_factor: float = 0.5  # 이동 속도 배율
@export var slow_duration: float = 2.5

@export_group("감전·연쇄")
@export var shock_duration: float = 3.0
@export var chain_count: int = 3
@export var chain_range: float = 230.0
@export_range(0.0, 2.0, 0.05) var chain_damage_ratio: float = 0.6

@export_group("반응")
@export var reaction_cooldown: float = 1.0
@export var steam_base_damage: float = 25.0
@export var steam_radius: float = 170.0
@export var spread_radius: float = 220.0
@export var freeze_duration: float = 1.5
@export var freeze_immunity: float = 3.0

@export_group("성")
@export var castle_hp: int = 30

@export_group("웨이브")
@export var wave_count: int = 15
## 웨이브 예산 = budget_base + budget_per_wave * (웨이브-1). 적마다 비용을 뺀다.
@export var budget_base: float = 8.0
@export var budget_per_wave: float = 3.0
@export var cost_runner: float = 1.0
@export var cost_swarm: float = 0.5
@export var cost_tank: float = 4.0
@export var tank_from_wave: int = 3
@export var gap_start: float = 3.5  # 무리 사이 간격 (1웨이브)
@export var gap_end: float = 2.0  # (마지막 웨이브)
@export var slot_upgrade_from_wave: int = 4  # 이 웨이브를 깬 뒤부터 룬 칸 +1 반드시 등장

@export_group("보스")
@export var boss_waves: PackedInt32Array = PackedInt32Array([5, 10, 15])
@export var boss_hp_multipliers: PackedFloat32Array = PackedFloat32Array([1.0, 2.2, 3.6])
@export var boss_trait_counts: PackedInt32Array = PackedInt32Array([1, 2, 2])
@export var boss_spawn_time: float = 2.0  # 웨이브 시작 몇 초 뒤 등장
@export_range(0.0, 1.0, 0.05) var boss_wave_budget_ratio: float = 0.5  # 보스 웨이브 일반 적 예산 비율
@export var max_enemy_speed: float = 300.0  # 돌진 등으로 빨라져도 이 이상은 안 됨
