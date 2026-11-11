#!/usr/bin/env bash
# 지금 브랜치를 웹으로 내보내고 띄운다 (맥, 윈도우 WSL). PC는 브라우저로, 휴대폰은 같은 와이파이에서 접속해 플레이한다(맥).
# 사용: bash tools/play_local.sh        (Godot 경로가 다르면 GODOT=경로 bash tools/play_local.sh)
# 끝낼 때는 Ctrl+C. 처음 실행하면 macOS가 "들어오는 연결 허용?"을 물을 수 있음 → 허용 (휴대폰 접속에 필요)
set -euo pipefail
cd "$(dirname "$0")/.."
MAC_GODOT=/Users/jaehyo/Downloads/Godot.app/Contents/MacOS/Godot
[ -x "$MAC_GODOT" ] && GODOT="${GODOT:-$MAC_GODOT}" || GODOT="${GODOT:-godot}"
PORT="${PORT:-8000}"

"$GODOT" --headless --path . --import >/dev/null 2>&1
mkdir -p build/web
"$GODOT" --headless --path . --export-release "Web" "$PWD/build/web/index.html" >/dev/null 2>&1
[ -f build/web/index.pck ] || { echo "웹 내보내기 실패 (웹 내보내기 템플릿 확인)" >&2; exit 1; }

echo "브랜치: $(git rev-parse --abbrev-ref HEAD) ($(git rev-parse --short HEAD))"
echo "PC:              http://localhost:$PORT/   (WSL이면 윈도우 브라우저에서 이 주소)"
if grep -qi microsoft /proc/version 2>/dev/null; then
	echo "휴대폰: WSL은 윈도우 포트 전달 설정이 따로 필요해 이 스크립트로는 안 됨 (맥에서 하거나 PC 브라우저의 휴대폰 크기 보기로)"
else
	IP=$(ipconfig getifaddr en0 2>/dev/null || ipconfig getifaddr en1 2>/dev/null || echo "맥의-IP")
	echo "휴대폰(같은 와이파이): http://$IP:$PORT/   (가로로 돌려서)"
fi
echo "끝내려면 Ctrl+C"
# 스레드 없는 웹 내보내기라 특별한 헤더 없이 기본 웹 서버로 열린다
python3 -m http.server "$PORT" --bind 0.0.0.0 --directory build/web
