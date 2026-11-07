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
| Pillow | MIT-CMU (HPND) | 시안 비교 이미지 붙이기, 자세 자르기·정렬 (개발 PC에서만 실행) |
| NumPy | BSD-3-Clause | `tools/cut_parts.py` 시트 배경 제거, `tools/align_frames.py` 프레임 정렬 (개발 PC에서만 실행) |
| SciPy | BSD-3-Clause | `tools/cut_parts.py` 시트에서 자세 찾기 (개발 PC에서만 실행) |

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
| `assets/raw/cat_parts_sheet.png` | 2026-11-07 | Codex 내장 이미지 생성 (기준 그림과 참고 시트를 첨부) | 고양이 부품 시트 원본: 머리, 몸통(초록 목도리), 꼬리, 앞다리 2, 뒷다리 2 (게임에 포함 안 됨) | 없음 |
| `assets/sprites/cat_parts/*.png` | 2026-11-07 | 위 원본 | v0.1.0의 고양이 그림 (Skeleton2D 뼈대). v0.1.1부터 쓰지 않고 내보내기에서 제외, 기록용으로 보관 | `tools/cut_parts.py`로 마젠타 배경을 지우고 부품 7개를 잘라 냄 |
| `assets/raw/cat_frames_run.png` | 2026-11-07 | Codex 내장 이미지 생성 (기준 그림과 동작 참고 6장을 첨부) | 달리기 4자세 시트 원본 (게임에 포함 안 됨) | 없음 |
| `assets/raw/cat_frames_jump.png` | 2026-11-07 | Codex 내장 이미지 생성 (기준 그림과 동작 참고 6장을 첨부) | 점프·떨어짐 6자세 시트 원본: 웅크리기, 도약, 올라감, 내려옴, 착지, 떨어짐 (게임에 포함 안 됨) | 없음 |
| `assets/sprites/cat_frames/*.png` | 2026-11-07 | 위 원본 2장 | 게임 속 고양이 그림 (프레임 애니메이션 10장) | `tools/cut_parts.py`로 마젠타 배경을 지우고 자세를 잘라 냄 → `tools/align_frames.py`로 크기(시트별 배율)·발끝·몸 중심을 맞춰 640x512 캔버스에 놓음 |
| `assets/raw/items_sheet.png` | 2026-11-07 | Codex 내장 이미지 생성 (기준 그림을 그림체 참고로 첨부) | 아이템 시트 원본: 생선, 종이상자 (게임에 포함 안 됨) | 없음 |
| `assets/sprites/items/fish.png`, `box.png` | 2026-11-07 | 위 원본 | 게임 속 생선·종이상자 그림, 왼쪽 위 생선·상자 표시 | `tools/cut_parts.py`로 마젠타 배경을 지우고 잘라 냄 → 너비 240픽셀로 줄임 |
| `assets/raw/structures_concept.png` | 2026-11-07 | Codex 내장 이미지 생성 (기준 그림을 그림체 참고로 첨부) | 구조물 콘셉트 시안(연두 배경): 빨래줄, 전봇대 (게임에 포함 안 됨) | 없음 |
| `assets/raw/structures_sheet.png` | 2026-11-07 | Codex 내장 이미지 생성 (위 시안을 `--image`로 첨부해 마젠타 배경으로 다시 그림) | 구조물 시트 원본 (게임에 포함 안 됨) | 없음 |
| `assets/sprites/structures/clothesline.png`, `pole.png` | 2026-11-07 | 위 원본 | 게임 속 빨래줄·전봇대 그림 | `tools/cut_parts.py`로 마젠타 배경을 지우고 잘라 냄 → 빨래줄은 너비 500픽셀로 줄이고, 전봇대는 원본 크기(267x767) 그대로 |
| `assets/raw/neighborhood_concept.png` | 2026-11-08 | Codex 내장 이미지 생성 (고양이·구조물 그림을 `--image`로 첨부해 그림체를 맞춤) | 주택가 건물 3종·옥상 소품 6종 시안·원본(마젠타 배경, 게임에 포함 안 됨) | 없음 |
| `assets/sprites/buildings/*.png` | 2026-11-08 | 위 원본 | 게임 속 주택가 건물 조각(왼쪽 캡·가운데·오른쪽 캡)과 옥상 소품 | `tools/cut_buildings.py`로 마젠타 배경을 지우고 지붕 위 실외기·화분은 건물에서 지워 소품으로 분리, 건물은 0.8배·소품은 0.7배로 줄임 |

## 직접 만든 것

- 프로젝트 아이콘 `icon.svg`: 이 프로젝트에서 직접 만듦
