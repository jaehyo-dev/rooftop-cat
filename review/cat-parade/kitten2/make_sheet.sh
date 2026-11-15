#!/usr/bin/env bash
# 아기 고양이 동작 시트 (Codex 내장 이미지 생성). 사용: bash review/cat-parade/kitten2/make_sheet.sh <품종> <차례>
# 예: make_sheet.sh cheese 1 → assets/raw/kittens/cheese_1.png. 다시 뽑을 때 고칠 점은 3번째 인자로 덧붙임.
# 결과는 출력의 session id 폴더 ~/.codex/generated_images/<id>/ 에서 가져온다 (CLAUDE.md)
set -uo pipefail
cd "$(dirname "$0")/../../.."
P=review/cat-parade/kitten2/prompts
mkdir -p logs assets/raw/kittens
LOG=logs/kitten_$1_$2.log
echo "=== [$(date '+%F %T')] Codex 작업: 아기 동작 시트 $1 $2 ===" >> logs/codex.log
REQ="$(cat $P/common.txt)

$(cat $P/$1.txt)
${3:-}

내장 이미지 생성 도구만 사용하고, 스크립트를 만들거나 API를 호출하지 마"
codex exec --sandbox read-only "$REQ" --image $P/ref_$1.png --image $P/pose_guide.png < /dev/null 2>&1 | tee $LOG >> logs/codex.log
ID=$(grep -m1 -o 'session id: [0-9a-f-]*' $LOG | cut -d' ' -f3)
IMG=$(ls -t ~/.codex/generated_images/$ID/*.png 2>/dev/null | head -1)
[ -n "$IMG" ] && cp "$IMG" assets/raw/kittens/$1_$2.png && echo "저장: assets/raw/kittens/$1_$2.png" || echo "그림 없음 ($ID)"
