#!/usr/bin/env bash
# 아기 고양이 시안 (Codex 내장 이미지 생성). 사용: bash review/cat-parade/kitten/make_kittens.sh 01_round|02_rascal
# 결과는 출력의 session id 폴더 ~/.codex/generated_images/<id>/ 에서 가져온다 (CLAUDE.md)
set -uo pipefail
cd "$(dirname "$0")/../../.."
P=review/cat-parade/kitten/prompts
mkdir -p logs
echo "=== [$(date '+%F %T')] Codex 작업: 아기 고양이 시안 $1 ===" >> logs/codex.log
REQ="$(cat $P/common.txt)

$(cat $P/$1.txt)

내장 이미지 생성 도구만 사용하고, 스크립트를 만들거나 API를 호출하지 마"
codex exec --sandbox read-only "$REQ" --image assets/concept/cat_reference_sheet.png --image assets/sprites/cat_base_run.png < /dev/null 2>&1 | tee -a logs/codex.log
