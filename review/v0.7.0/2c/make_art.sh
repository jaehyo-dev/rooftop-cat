#!/usr/bin/env bash
# v0.7.0 2c 그림 시트 2장 (Codex 내장 이미지 생성). 결과는 assets/raw/로 복사
# 사용: bash review/v0.7.0/2c/make_art.sh
set -uo pipefail
cd "$(dirname "$0")/../../.."
run() {  # 이름, 요청문 파일, 첨부...
	local name=$1 prompt=$2; shift 2
	local args=()
	for img in "$@"; do args+=(--image "$img"); done
	echo "=== [$(date '+%F %T')] Codex 작업: 2c 그림 $name ===" >> logs/codex.log
	local out
	out=$(codex exec --sandbox read-only "$(cat "$prompt")" "${args[@]}" < /dev/null 2>&1 | tee -a logs/codex.log)
	local sid
	sid=$(echo "$out" | grep -a -m1 "session id" | awk '{print $3}')
	local png
	png=$(ls -t ~/.codex/generated_images/"$sid"/*.png 2>/dev/null | head -1)
	if [ -n "$png" ]; then cp "$png" "assets/raw/$name.png"; echo "$name: $png"; else echo "$name: 그림 없음 ($sid)"; fi
}
run ui_paper_sheet review/v0.7.0/2c/prompts/ui_paper.txt review/v0.7.0/concept/05_shop_B.png review/v0.7.0/concept/08_mission_B.png
run ui_icons_sheet review/v0.7.0/2c/prompts/icons.txt assets/raw/items_sheet.png assets/sprites/cat_base_run.png
