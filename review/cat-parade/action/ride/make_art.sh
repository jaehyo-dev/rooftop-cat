#!/usr/bin/env bash
# 구름 타기 그림 (Codex 내장 이미지 생성). 사용: bash review/cat-parade/action/ride/make_art.sh <ride|cloud> <차례> [덧붙일 말]
# ride: 첨부 = prompts/ref_cheese_alive.png(지금 치즈 앉은·엎드린 그림 2배) + 다른 아기 그림체 ref_style.png → assets/raw/kitten_alive/cheese_ride_<차례>.png
# cloud: 첨부 = ref_style.png + prompts/ref_cloud.png(하늘 구름) → assets/raw/kitten_alive/cloud_ride_<차례>.png
set -uo pipefail
cd "$(dirname "$0")/../../../.."
P=review/cat-parade/action/ride/prompts
STYLE=review/cat-parade/action/alive/prompts/ref_style.png
mkdir -p logs assets/raw/kitten_alive
KIND=$1; TRY=$2
LOG=logs/ride_${KIND}_${TRY}.log
echo "=== [$(date '+%F %T')] Codex 작업: 구름 타기 그림 $KIND $TRY ===" >> logs/codex.log
REQ="$(cat $P/$KIND.txt)
${3:-}

내장 이미지 생성 도구만 사용하고, 스크립트를 만들거나 API를 호출하지 마"
if [ "$KIND" = ride ]; then REFS="$P/ref_cheese_alive.png $STYLE"; OUT=assets/raw/kitten_alive/cheese_ride_${TRY}.png
else REFS="$STYLE $P/ref_cloud.png"; OUT=assets/raw/kitten_alive/cloud_ride_${TRY}.png; fi
codex exec --sandbox read-only "$REQ" --image $REFS < /dev/null 2>&1 | tee $LOG >> logs/codex.log
ID=$(grep -m1 -o 'session id: [0-9a-f-]*' $LOG | cut -d' ' -f3)
IMG=$(ls -t ~/.codex/generated_images/$ID/*.png 2>/dev/null | head -1)
[ -n "$IMG" ] && cp "$IMG" $OUT && echo "저장: $OUT" || echo "그림 없음 ($ID)"
