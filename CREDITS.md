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
| GitHub Actions: actions/checkout, actions/cache, actions/configure-pages, actions/upload-pages-artifact, actions/deploy-pages | MIT | `.github/` 자동 테스트·배포 |
| Python 3 표준 라이브러리 | PSF License | `tools/` 변경 기록·버전 도구 |
| rembg | MIT | 그림 배경 제거 (개발 PC에서만 실행) |
| Pillow | MIT-CMU (HPND) | 비교 이미지 만들기 `tools/make_contact_sheet.py` |

## AI로 만든 그림

Codex(ChatGPT 구독)의 내장 이미지 생성(gpt-image-2)으로 만들었습니다. 요청문은 [ASSET_PROMPTS.md](ASSET_PROMPTS.md)에 있습니다.
특정 게임·작품의 캐릭터를 따라 그리지 않도록 요청했습니다.

| 파일 | 만든 날 | 도구 | 쓰는 곳 | 수정 |
|---|---|---|---|---|
| `assets/raw/cat_concept_a~d.png` | 2026-11-06 | Codex 내장 이미지 생성 | 기준 고양이 시안 (원본, 게임에 포함 안 됨) | 없음 |
| `assets/sprites/cat_concept_a~d.png` | 2026-11-06 | 위 원본 + rembg | 배경을 지운 시안 | rembg로 배경 제거 |
| `assets/concept/cat_options.png` | 2026-11-06 | 위 시안 4장 | 시안 비교용 (게임에 포함 안 됨) | 4장을 나란히 붙임 |

## 직접 만든 것

- 프로젝트 아이콘 `icon.svg`: 이 프로젝트에서 직접 만듦
