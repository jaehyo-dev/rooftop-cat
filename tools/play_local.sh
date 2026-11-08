#!/usr/bin/env bash
# 지금 브랜치를 웹으로 내보내고 맥에서 띄운다. PC는 맥 브라우저로, 휴대폰은 같은 와이파이에서 접속해 플레이한다.
# 사용: bash tools/play_local.sh        (Godot 경로가 다르면 GODOT=경로 bash tools/play_local.sh)
# 끝낼 때는 Ctrl+C. 처음 실행하면 macOS가 "들어오는 연결 허용?"을 물을 수 있음 → 허용 (휴대폰 접속에 필요)
set -euo pipefail
cd "$(dirname "$0")/.."
GODOT="${GODOT:-/Users/jaehyo/Downloads/Godot.app/Contents/MacOS/Godot}"
PORT="${PORT:-8000}"

"$GODOT" --headless --path . --import >/dev/null 2>&1
mkdir -p build/web
"$GODOT" --headless --path . --export-release "Web" "$PWD/build/web/index.html" >/dev/null 2>&1
[ -f build/web/index.pck ] || { echo "웹 내보내기 실패 (웹 내보내기 템플릿 확인)" >&2; exit 1; }

IP=$(ipconfig getifaddr en0 2>/dev/null || ipconfig getifaddr en1 2>/dev/null || echo "맥의-IP")
echo "브랜치: $(git rev-parse --abbrev-ref HEAD) ($(git rev-parse --short HEAD))"
echo "PC(이 맥):        http://localhost:$PORT/"
echo "휴대폰(같은 와이파이): http://$IP:$PORT/   (가로로 돌려서)"
echo "끝내려면 Ctrl+C"
# 스레드 없는 웹 내보내기라 특별한 헤더 없이 기본 웹 서버로 열린다
python3 -m http.server "$PORT" --bind 0.0.0.0 --directory build/web
