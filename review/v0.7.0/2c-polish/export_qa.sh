#!/usr/bin/env bash
# 검수용 웹 빌드: 보통 웹 내보내기는 tools/를 빼므로, 잠깐 tools/를 넣어 build/qa에 내보내고 설정을 되돌린다.
# 사용: GODOT=<Godot 경로> bash review/v0.7.0/2c-juice/export_qa.sh
set -euo pipefail
cd "$(dirname "$0")/../../.."
cp export_presets.cfg /tmp/export_presets.cfg.keep
trap 'cp /tmp/export_presets.cfg.keep export_presets.cfg' EXIT
sed -i '' 's|exclude_filter="tests/\*, tools/\*, |exclude_filter="tests/*, tools/*.py, tools/__pycache__/*, |' export_presets.cfg
mkdir -p build/qa
"${GODOT:-godot}" --headless --path . --export-release "Web" "$PWD/build/qa/index.html" >/dev/null 2>&1
[ -f build/qa/index.pck ] && echo "build/qa 내보냄"
