#!/usr/bin/env bash
# 6마리 움직임 마무리 시트 (Codex 내장 이미지 생성). 사용: bash review/cat-parade/final/make_sheet.sh <종류> <품종> <차례> [덧붙일 말]
# 종류: frames(달리기 8 + 땅·공중 6, 걸음 안내도 첨부) / air(공중 13) / scared(놀람 3)
# 요청문 = prompts/<종류>.txt 의 {BREED} 자리에 review/cat-parade/kitten2/prompts/<품종>.txt
# 첨부 = 그 아기 기준 그림(kitten2 ref_<품종>) + 종류별 그림 (아래). 결과: assets/raw/kitten_motion/<품종>_<종류>_<차례>.png
set -uo pipefail
cd "$(dirname "$0")/../../.."
P=review/cat-parade/final/prompts
M=review/cat-parade/motion/prompts
mkdir -p logs assets/raw/kitten_motion
KIND=$1; BREED=$2; TRY=$3
case $KIND in
  frames) EXTRA="$M/a_guide.png" ;;
  air) EXTRA="$P/ref_${BREED}_frames.png $M/ref_hero_air.png" ;;
  scared) EXTRA="$P/ref_${BREED}_scared.png" ;;
  *) echo "종류: frames / air / scared"; exit 1 ;;
esac
LOG=logs/final_${BREED}_${KIND}_${TRY}.log
echo "=== [$(date '+%F %T')] Codex 작업: 아기 시트 $KIND $BREED $TRY ===" >> logs/codex.log
DESC="$(cat review/cat-parade/kitten2/prompts/$BREED.txt)"
TPL="$(cat $P/$KIND.txt)"
REQ="${TPL//\{BREED\}/$DESC}
${4:-}

내장 이미지 생성 도구만 사용하고, 스크립트를 만들거나 API를 호출하지 마"
codex exec --sandbox read-only "$REQ" --image review/cat-parade/kitten2/prompts/ref_$BREED.png $(for f in $EXTRA; do printf -- "--image %s " "$f"; done) < /dev/null 2>&1 | tee $LOG >> logs/codex.log
ID=$(grep -m1 -o 'session id: [0-9a-f-]*' $LOG | cut -d' ' -f3)
IMG=$(ls -t ~/.codex/generated_images/$ID/*.png 2>/dev/null | head -1)
OUT=assets/raw/kitten_motion/${BREED}_${KIND}_${TRY}.png
[ -n "$IMG" ] && cp "$IMG" $OUT && echo "저장: $OUT" || echo "그림 없음 ($ID)"
