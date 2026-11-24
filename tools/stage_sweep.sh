#!/usr/bin/env bash
# 스테이지별로 봇을 돌려 [battle]·[metrics] 줄만 모은다 (스테이지 수치, 그 스테이지 첫 판의 룬, 영구 강화는 셋째 인자 레벨).
# 사용: bash tools/stage_sweep.sh "1 2 3" switch 2 [ember]   (Godot 경로는 GODOT 환경 변수)
G=${GODOT:-/d/Godot/Godot_v4.7.2-stable_win64_console.exe}
STAGES=${1:-"1 2 3 4 5 6 7 8 9 10"}
BOT=${2:-switch}
PERM=${3:-0}  # 영구 강화 레벨 (전 항목, 상한까지)
FV=${4:-}  # 불 변형 id (ember / blaze / backfire / backfire_rem / backfire_charge, 빈 값 = 기본)
cd "$(dirname "$0")/.."
for s in $STAGES; do
  timeout 900 "$G" --headless --path . --fixed-fps 30 --quit-after 60000 res://scenes/main.tscn -- --bot=$BOT --stage=$s --perm=$PERM ${FV:+--fire-variant=$FV} --quit-on-end 2>&1 | grep -E "\[(battle|metrics)\]"
done
