# 크레딧과 라이선스

이 게임에 쓰인 외부 오픈소스·에셋의 출처와 라이선스입니다.
새로 추가하거나 버전을 바꿀 때마다 이 파일을 함께 고칩니다 (규칙: [CLAUDE.md](CLAUDE.md)의 "오픈소스 사용 규칙").

배포된 게임에서는 `licenses/` 경로에 이 파일과 라이선스 전문이 함께 올라갑니다.

## 게임에 포함된 것

| 이름 | 버전 | 만든 사람 | 라이선스 | 출처 | 쓰는 곳 | 수정 |
|---|---|---|---|---|---|---|
| Godot Engine | 4.7.2-stable | Godot Engine contributors, Juan Linietsky, Ariel Manzur | MIT (엔진에 포함된 서드파티 구성 요소는 각자의 라이선스) | https://godotengine.org | 게임 엔진, 웹 내보내기 템플릿 | 없음 |

- Godot 엔진과 엔진 구성 요소의 라이선스 전문은 배포할 때 `licenses/godot.txt`로 자동 생성합니다 (`tools/export_licenses.gd`).

## 개발·배포에만 쓰는 것 (게임에는 포함되지 않음)

| 이름 | 라이선스 | 쓰는 곳 |
|---|---|---|
| GitHub Actions: actions/checkout, actions/cache, actions/upload-artifact, actions/configure-pages, actions/upload-pages-artifact, actions/deploy-pages | MIT | `.github/` 자동 테스트·배포 |
| Python 3 표준 라이브러리 | PSF License | `tools/` 변경 기록·버전 도구 |
| rembg 2.x + isnet-general-use 모델 | MIT (rembg), Apache-2.0 (IS-Net) | 그림 배경 제거 (개발 PC에서만 실행). 기본 모델 BRIA RMBG-2.0은 비상업 라이선스라 쓰지 않음 |
| Pillow | MIT-CMU (HPND) | 시안 비교 이미지 붙이기 (개발 PC에서만 실행) |

## AI로 만든 그림

Codex(ChatGPT 구독)의 내장 이미지 생성(gpt-image-2)으로 만들었습니다. 요청문은 [ASSET_PROMPTS.md](ASSET_PROMPTS.md)에 있습니다.
특정 게임·작품의 캐릭터를 따라 그리지 않도록 요청했습니다.

| 파일 | 만든 날 | 도구 | 쓰는 곳 | 수정 |
|---|---|---|---|---|
| `assets/raw/cat_concept_a~d.png` | 2026-11-06 | Codex 내장 이미지 생성 | 기준 고양이 시안 (원본, 게임에 포함 안 됨) | 없음 |
| `assets/raw/cat_concept_e.png` | 2026-11-06 | Codex 내장 이미지 생성 (시안 C를 기준 그림으로 첨부) | 기준 고양이 시안 E: C + 수채 질감 (원본, 게임에 포함 안 됨) | 없음 |
| `assets/sprites/cat_concept_a~e.png` | 2026-11-06 | 위 원본 + rembg | 배경을 지운 시안 (게임 내보내기에서 제외) | rembg(isnet-general-use)로 배경 제거 |
| `assets/concept/cat_options.png` | 2026-11-06 | 위 시안 4장 | 시안 비교용 (게임에 포함 안 됨) | 4장을 잘라 나란히 붙이고 글자(macOS 기본 글꼴 Apple SD Gothic Neo)를 넣음 |
| `assets/concept/cat_c_vs_e.png` | 2026-11-06 | 시안 C, E | C와 E 비교용 (게임에 포함 안 됨) | 2장을 잘라 나란히 붙이고 글자를 넣음 |
| `assets/raw/cat_mascot_i~k.png` | 2026-11-06 | Codex 내장 이미지 생성 | 마스코트 시안 I·J·K: 고양이 모티브 단순 캐릭터 (원본, 게임에 포함 안 됨) | 없음 |
| `assets/sprites/cat_mascot_i~k.png` | 2026-11-06 | 위 원본 | 배경을 지운 마스코트 시안 (게임 내보내기에서 제외) | 연두 배경을 초록 우세도(G - max(R, B))로 지움 (rembg는 닫힌 틈에 배경이 남고 몸이 반투명해져 쓰지 않음) |
| `assets/concept/cat_mascot.png` | 2026-11-06 | 시안 I·J·K | 마스코트 비교용 (게임에 포함 안 됨) | 3장을 잘라 나란히 붙이고 글자를 넣음 |
| `assets/concept/cat_reference_sheet.png` | 2026-11-06 | 사용자가 다른 세션에서 AI로 만들어 제공 (요청문 기록 없음) | 기준 캐릭터 참고 시트, 6가지 동작 (게임에 포함 안 됨) | 없음 |
| `assets/concept/poses/walk·crouch·run·jump·land·dash.png` | 2026-11-06 | 위 참고 시트 | 모션 참고용 동작 6장 (게임에 포함 안 됨) | 시트에서 잘라 남색 배경을 색 거리로 지움 |
| `assets/raw/cat_base_run.png` | 2026-11-06 | Codex 내장 이미지 생성 (참고 시트와 run 동작을 기준 그림으로 첨부) | 기준 캐릭터 달리는 옆모습 원본 (게임에 포함 안 됨) | 없음 |
| `assets/sprites/cat_base_run.png` | 2026-11-06 | 위 원본 | 기준 그림 (3단계에서 고양이 그림의 기준) | 마젠타 배경을 마젠타 우세도(min(R, B) - G)로 지우고 1024x1024로 줄임 |

## 직접 만든 것

- 프로젝트 아이콘 `icon.svg`: 이 프로젝트에서 직접 만듦
