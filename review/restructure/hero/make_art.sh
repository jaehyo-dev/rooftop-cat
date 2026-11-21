#!/usr/bin/env bash
# 카툰 주인공 그림 (Codex 내장 이미지 생성). 사용: bash review/restructure/hero/make_art.sh <장면> <차례> <첨부...> [-- 덧붙일 말]
# 요청문 = prompts/common.txt + prompts/<장면>.txt + 덧붙일 말. 첫 첨부는 기준 그림 assets/concept/cartoon/hero_reference.png.
# 결과는 assets/concept/cartoon/<장면>_<차례>.png
set -uo pipefail
cd "$(dirname "$0")/../../.."
P=review/restructure/hero/prompts
OUTDIR=assets/concept/cartoon/hero
SC=$1; TRY=$2; shift 2
REFS=(); while [ $# -gt 0 ] && [ "$1" != "--" ]; do REFS+=("$1"); shift; done
[ "${1:-}" = "--" ] && shift
EXTRA="${*:-}"
mkdir -p logs $OUTDIR
LOG=logs/hero_${SC}_${TRY}.log
echo "=== [$(date '+%F %T')] Codex 작업: 카툰 $SC $TRY ===" >> logs/codex.log
REQ="$(cat $P/common.txt)
$(cat $P/$SC.txt)
$EXTRA

내장 이미지 생성 도구만 사용하고, 스크립트를 만들거나 API를 호출하지 마"
codex exec --sandbox read-only "$REQ" --image "${REFS[@]}" < /dev/null 2>&1 | tee $LOG >> logs/codex.log
ID=$(grep -m1 -o 'session id: [0-9a-f-]*' $LOG | cut -d' ' -f3)
IMG=$(ls -t ~/.codex/generated_images/$ID/*.png 2>/dev/null | head -1)
OUT=$OUTDIR/${SC}_${TRY}.png
[ -n "$IMG" ] && cp "$IMG" $OUT && echo "저장: $OUT" || echo "그림 없음 ($ID)"
