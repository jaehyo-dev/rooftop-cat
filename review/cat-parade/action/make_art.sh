#!/usr/bin/env bash
# 액션 시험판 그림 (Codex 내장 이미지 생성): bash review/cat-parade/action/make_art.sh sign|slide
# 결과는 출력의 session id 폴더에서 assets/raw/action/<이름>.png로 복사
set -euo pipefail
cd "$(dirname "$0")/../../.."
name=$1
case $name in
	sign) images=(assets/sprites/obstacles/ac.png assets/sprites/obstacles/pot.png) ;;
	slide) images=(assets/sprites/cat_base_run.png assets/sprites/cat_frames/run_1.png) ;;
esac
mkdir -p logs assets/raw/action
echo "=== [$(date '+%F %T')] Codex 작업: 액션 시험판 그림 $name ===" >> logs/codex.log
args=()
for i in "${images[@]}"; do args+=(--image "$i"); done
out=$(codex exec --sandbox read-only "$(cat review/cat-parade/action/prompts/$name.txt)" "${args[@]}" < /dev/null 2>&1 | tee -a logs/codex.log)
sid=$(echo "$out" | grep -o 'session id: [0-9a-f-]*' | head -1 | cut -d' ' -f3)
f=$(ls -t ~/.codex/generated_images/$sid/*.png | head -1)
cp "$f" assets/raw/action/$name.png
echo "저장: assets/raw/action/$name.png ($f)"
