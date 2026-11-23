#!/usr/bin/env bash
# 전략 봇 3종을 여러 시드로 돌려 [battle] 줄만 모은다.
# 사용: bash tools/bot_compare.sh "1 2 3 4 5"   (Godot 경로는 GODOT 환경 변수, 기본 D:/Godot 콘솔판)
G=${GODOT:-/d/Godot/Godot_v4.7.2-stable_win64_console.exe}
SEEDS=${1:-"12345 1 2 3 4"}
cd "$(dirname "$0")/.."
for s in $SEEDS; do
  for b in fire duo switch; do
    timeout 600 "$G" --headless --path . --fixed-fps 30 --quit-after 40000 -- --bot=$b --seed=$s --quit-on-end 2>&1 | grep "\[battle\]" | sed "s/^/seed=$s /"
  done
done
