#!/bin/bash
# v0.7.0 시안 만들기: prompts/*.txt를 하나씩 Codex(내장 이미지 생성)에 넘기고 결과를 <번호_이름>.png로 복사한다.
# 실행: bash review/v0.7.0/concept/make_concepts.sh [이름...]   (저장소 루트에서)
cd "$(git rev-parse --show-toplevel)" || exit 1
D=review/v0.7.0/concept
mkdir -p logs
names=("$@")
[ ${#names[@]} -eq 0 ] && names=($(cd "$D/prompts" && ls *.txt | sed 's/\.txt$//'))
for n in "${names[@]}"; do
  [ -f "$D/$n.png" ] && { echo "있음: $n"; continue; }
  case "$n" in
    *fish*) refs=(assets/sprites/items/fish.png assets/sprites/items/gold.png) ;;
    *) refs=(review/v0.6.0/release/version_pc_1280x720.png review/v0.6.0/2b/fix/result_pc_1280x720.png) ;;
  esac
  echo "=== [$(date '+%Y-%m-%d %H:%M:%S')] Codex 작업: v0.7.0 시안 $n ===" >> logs/codex.log
  out=$(codex exec --sandbox read-only "$(cat "$D/prompts/$n.txt")" --image "${refs[@]}" < /dev/null 2>&1 | tee -a logs/codex.log)
  sid=$(echo "$out" | grep -m1 -i "session id" | grep -oE '[0-9a-f]{8}-[0-9a-f-]{27}')
  img=$(ls -t ~/.codex/generated_images/"$sid"/*.png 2>/dev/null | head -1)
  if [ -n "$img" ]; then cp "$img" "$D/$n.png"; echo "완료: $n"; else echo "실패: $n (session $sid)"; fi
done
