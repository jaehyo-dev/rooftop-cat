#!/usr/bin/env bash
# 화풍 시안 (Codex 내장 이미지 생성). 사용: bash review/restructure/style/make_art.sh <1|2|3> <A|B|C> <차례> [덧붙일 말]
# 화풍 2·3은 같은 장면의 화풍 1 결과를 구도 기준으로 함께 첨부한다(구도가 같아야 공정하게 비교됨).
# 결과는 s<화풍>_<장면>_<차례>.png. 고른 것을 s<화풍>_<장면>.png로 이름을 바꾸면 compose.py와 화풍 2·3 첨부가 그걸 쓴다.
set -uo pipefail
cd "$(dirname "$0")/../../.."
P=review/restructure/style/prompts
RAW=assets/concept/restructure_style
mkdir -p logs $RAW
S=$1; SC=$2; TRY=$3
LOG=logs/style_${S}${SC}_${TRY}.log
echo "=== [$(date '+%F %T')] Codex 작업: 화풍 시안 $S $SC $TRY ===" >> logs/codex.log
REFS="$P/ref_game.png $P/ref_cats.png $P/ref_hero.png"
EXTRA=""
if [ "$S" != 1 ]; then
  REFS="$REFS $RAW/s1_${SC}.png"
  EXTRA="4번 = 같은 장면의 다른 화풍 시안. 구도·카메라·인물 자세·사물 배치·크기는 4번과 똑같이 하고 화풍만 바꿔."
fi
REQ="$(cat $P/common.txt)
$EXTRA
$(cat $P/style$S.txt)
$(cat $P/scene$SC.txt)
${4:-}

내장 이미지 생성 도구만 사용하고, 스크립트를 만들거나 API를 호출하지 마"
codex exec --sandbox read-only "$REQ" --image $REFS < /dev/null 2>&1 | tee $LOG >> logs/codex.log
ID=$(grep -m1 -o 'session id: [0-9a-f-]*' $LOG | cut -d' ' -f3)
IMG=$(ls -t ~/.codex/generated_images/$ID/*.png 2>/dev/null | head -1)
OUT=$RAW/s${S}_${SC}_${TRY}.png
[ -n "$IMG" ] && cp "$IMG" $OUT && echo "저장: $OUT" || echo "그림 없음 ($ID)"
