#!/usr/bin/env bash
# 떠다니는 아기 "살아 움직이기" 동작 시트 (Codex 내장 이미지 생성). 사용: bash review/cat-parade/action/alive/make_sheet.sh <품종> <차례> [덧붙일 말]
# 요청문 = prompts/alive.txt, 첨부 = prompts/ref_<품종>_wait.png (wait.png 몸만 / 꼬리 붙인 모습, 2배). 결과: assets/raw/kitten_alive/<품종>_<차례>.png
set -uo pipefail
cd "$(dirname "$0")/../../../.."
P=review/cat-parade/action/alive/prompts
mkdir -p logs assets/raw/kitten_alive
BREED=$1; TRY=$2
LOG=logs/alive_${BREED}_${TRY}.log
echo "=== [$(date '+%F %T')] Codex 작업: 아기 살아 움직이기 시트 $BREED $TRY ===" >> logs/codex.log
REQ="$(cat $P/alive.txt)
${3:-}

내장 이미지 생성 도구만 사용하고, 스크립트를 만들거나 API를 호출하지 마"
codex exec --sandbox read-only "$REQ" --image $P/ref_${BREED}_wait.png < /dev/null 2>&1 | tee $LOG >> logs/codex.log
ID=$(grep -m1 -o 'session id: [0-9a-f-]*' $LOG | cut -d' ' -f3)
IMG=$(ls -t ~/.codex/generated_images/$ID/*.png 2>/dev/null | head -1)
OUT=assets/raw/kitten_alive/${BREED}_${TRY}.png
[ -n "$IMG" ] && cp "$IMG" $OUT && echo "저장: $OUT" || echo "그림 없음 ($ID)"
