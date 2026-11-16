#!/usr/bin/env bash
# 아기 움직임 비교용 시트 (Codex 내장 이미지 생성). 사용: bash review/cat-parade/motion/make_sheet.sh <a_frames|b_parts> <차례> [덧붙일 말]
# EXTRA_IMAGE="<그림> [그림 ...]" 이면 두 번째 그림부터 함께 넘김 (A 2차: 발 위치 안내도, motion2: 기존 아기 그림·안내도)
# 결과: assets/raw/kitten_motion/<이름>_<차례>.png (출력의 session id 폴더에서 가져옴, CLAUDE.md)
set -uo pipefail
cd "$(dirname "$0")/../../.."
P=review/cat-parade/motion/prompts
mkdir -p logs assets/raw/kitten_motion
LOG=logs/motion_$1_$2.log
echo "=== [$(date '+%F %T')] Codex 작업: 아기 움직임 시트 $1 $2 ===" >> logs/codex.log
REQ="$(cat $P/$1.txt)
${3:-}

내장 이미지 생성 도구만 사용하고, 스크립트를 만들거나 API를 호출하지 마"
codex exec --sandbox read-only "$REQ" --image $P/ref_cheese.png $(for f in ${EXTRA_IMAGE:-}; do printf -- "--image %s " "$f"; done) < /dev/null 2>&1 | tee $LOG >> logs/codex.log
ID=$(grep -m1 -o 'session id: [0-9a-f-]*' $LOG | cut -d' ' -f3)
IMG=$(ls -t ~/.codex/generated_images/$ID/*.png 2>/dev/null | head -1)
[ -n "$IMG" ] && cp "$IMG" assets/raw/kitten_motion/$1_$2.png && echo "저장: assets/raw/kitten_motion/$1_$2.png" || echo "그림 없음 ($ID)"
