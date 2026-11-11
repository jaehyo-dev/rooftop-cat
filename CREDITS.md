# 크레딧과 라이선스

이 게임에 쓰인 외부 오픈소스·에셋의 출처와 라이선스입니다.
새로 추가하거나 버전을 바꿀 때마다 이 파일을 함께 고칩니다 (규칙: [CLAUDE.md](CLAUDE.md)의 "오픈소스 사용 규칙").

배포된 게임에서는 `licenses/` 경로에 이 파일과 라이선스 전문이 함께 올라갑니다.

## 게임에 포함된 것

| 이름 | 버전 | 만든 사람 | 라이선스 | 출처 | 쓰는 곳 | 수정 |
|---|---|---|---|---|---|---|
| Godot Engine | 4.7.2-stable | Godot Engine contributors, Juan Linietsky, Ariel Manzur | MIT (엔진에 포함된 서드파티 구성 요소는 각자의 라이선스) | https://godotengine.org | 게임 엔진, 웹 내보내기 템플릿 | 없음 |
| Gaegu Bold (`Gaegu-Bold.ttf`) | google/fonts 커밋 86aced9 | The Gaegu Project Authors (JIKJI SOFT) | SIL OFL 1.1 | https://github.com/google/fonts/tree/86aced9/ofl/gaegu | `assets/fonts/gaegu/`, HUD·게임 끝 화면 글자 (`scenes/main.tscn` 테마) | 없음 (라이선스 전문 `assets/fonts/gaegu/LICENSE.txt` = 원래 `OFL.txt`) |

- Godot 엔진과 엔진 구성 요소의 라이선스 전문은 배포할 때 `licenses/godot.txt`로 자동 생성합니다 (`tools/export_licenses.gd`).

## 개발·배포에만 쓰는 것 (게임에는 포함되지 않음)

| 이름 | 라이선스 | 쓰는 곳 |
|---|---|---|
| GitHub Actions: actions/checkout, actions/cache, actions/upload-artifact, actions/configure-pages, actions/upload-pages-artifact, actions/deploy-pages | MIT | `.github/` 자동 테스트·배포 |
| Python 3 표준 라이브러리 | PSF License | `tools/` 변경 기록·버전 도구 |
| rembg 2.x + isnet-general-use 모델 | MIT (rembg), Apache-2.0 (IS-Net) | 그림 배경 제거 (개발 PC에서만 실행). 기본 모델 BRIA RMBG-2.0은 비상업 라이선스라 쓰지 않음 |
| FFmpeg (libvorbis) | LGPL/GPL 도구 (게임에 포함되지 않고 개발 PC에서 wav→ogg 변환에만 사용, 결과 파일에는 라이선스 영향 없음) | `tools/make_music.py` ogg 변환 (개발 PC에서만 실행) |
| Pillow | MIT-CMU (HPND) | 시안 비교 이미지 붙이기, 자세 자르기·정렬 (개발 PC에서만 실행) |
| NumPy | BSD-3-Clause | `tools/make_music.py` 배경 음악 합성, `tools/cut_parts.py` 시트 배경 제거, `tools/align_frames.py` 프레임 정렬 (개발 PC에서만 실행) |
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
| `assets/sprites/items/fish_0~3.png` | 2026-11-11 (2c에 씀) | Codex 내장 이미지 생성: v0.7.0 시안 10 "세트 1"(`review/v0.7.0/concept/10_fish_set1.png`) | 생선 점수 강화 0·3·6·10단계 생선 그림 (멸치·고등어·분홍 도미·하늘보라 물고기) | 마젠타 배경을 지우고(`tools/cut_parts.py`) 지금 생선과 같은 240x136 칸에 맞춤, 반짝이 조각은 뺌 (`review/v0.7.0/2c/cut_art.py`) |
| `assets/raw/ui_paper_sheet.png` → `assets/sprites/ui/panel·note·cork·button_orange·button_cream·pin_red·pin_yellow·clip.png` | 2026-11-12 | Codex 내장 이미지 생성 (시안 05·08 첨부) | 시작 화면·상점·미션·결과 카드의 종이 패널, 쪽지, 코르크판, 버튼, 압정, 빨래집게 | 마젠타 배경을 지우고 잘라 냄, 버튼은 높이 100으로 줄임 (`review/v0.7.0/2c/cut_art.py`) |
| `assets/raw/ui_icons_sheet.png` → `assets/sprites/ui/icons/*.png` (16개) | 2026-11-12 | Codex 내장 이미지 생성 (아이템 시트·기준 고양이 첨부) | 강화·부스터·미션 종류·바꾸기·등급 배지·상점·별·뒤로 아이콘 | 마젠타 배경을 지우고 4x4 칸으로 잘라 냄. `cookie_clock.png`는 지금 쿠키 그림에 시계 아이콘을 작게 겹쳐 붙임 |
| `assets/raw/ui_stamp.png` → `assets/sprites/ui/icons/stamp.png` | 2026-11-12 | Codex 내장 이미지 생성 (이 PC에서 그림이 되는지 시험한 그림) | 미션 받은 쪽지의 빨간 발바닥 도장 | 마젠타 배경을 지우고 잘라 냄 |
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
| `assets/raw/far_background.png` | 2026-11-08 | Codex 내장 이미지 생성 (주택가 시안·고양이 그림을 `--image`로 첨부해 그림체를 맞춤) | 먼 배경 시트 원본: 멀리 보이는 동네 띠 + 구름 4개 (마젠타 배경, 게임에 포함 안 됨) | 없음 |
| `assets/sprites/backdrop/far_town.png`, `cloud1~4.png` | 2026-11-08 | 위 원본 | 게임 속 먼 배경: 동네 띠(far_town), 구름(cloud1~4) | `tools/cut_parts.py`로 마젠타 배경을 지우고 잘라 냄 → 동네 띠 위아래 투명 여백을 잘라 냄 → `tools/clean_edges.py`로 가장자리 분홍 잔여물 정리 |
| `assets/raw/mist_bands.png`, `mist_silhouette.png` | 2026-11-08 | Codex 내장 이미지 생성 (시안 C·먼 배경 원본을 `--image`로 첨부해 그림체를 맞춤) | 안개 띠 3겹 시트, 안개 속 먼 지붕·나무·전봇대·전깃줄 실루엣 띠 원본 (마젠타 배경, 게임에 포함 안 됨) | 없음 |
| `assets/sprites/backdrop/mist_far.png`, `mist_mid.png`, `mist_near.png`, `mist_town.png` | 2026-11-08 | 위 원본 | v0.4.1 화면 아래 안개 겹(먼·가운데·맨 앞)과 안개 속 실루엣 | `tools/cut_parts.py`로 마젠타 배경을 지우고 잘라 냄 → 여백·아래 가장자리 섞인 줄 잘라 냄 → 안개 띠는 윗가장자리에서 아래로 90~110줄에 걸쳐 투명→불투명으로 부드럽게, 색을 크림색 쪽으로 30% 옅게 → `tools/clean_edges.py` |
| `assets/raw/trampoline_sheet.png` | 2026-11-08 | Codex 내장 이미지 생성 (주택가 건물 시안·구조물 시트를 `--image`로 첨부해 그림체를 맞춤) | 트램펄린 3상태 시트 원본: 평소·밟음·튕김 (마젠타 배경, 게임에 포함 안 됨) | 없음 |
| `assets/sprites/structures/trampoline_rest.png`, `trampoline_pressed.png`, `trampoline_launch.png` | 2026-11-08 | 위 원본 | 게임 속 트램펄린 (평소·밟음·튕김) | `tools/cut_parts.py`의 마젠타 지우기로 배경을 지우고 세 그림을 같은 캔버스(432x200)로 잘라 절반(216x100)으로 줄임 → `tools/clean_edges.py` |
| `review/v0.4.1/mockup_A_extend.png`, `mockup_B_alley.png`, `mockup_C_mist.png` | 2026-11-08 | Codex 내장 이미지 생성 (v0.4.0 캡처와 주택가 시안을 `--image`로 첨부) | v0.4.1 화면 아래 시안 A·B·C (검토용, 게임에 포함 안 됨) | 없음 |
| `assets/raw/cat_frames_flip.png` → `assets/sprites/cat_frames/flip_tuck.png`, `flip_curl.png`, `flip_ball.png`, `flip_open.png` | 2026-11-08 | Codex 내장 이미지 생성 (기준 그림·웅크림·도약 프레임을 `--image`로 첨부) | 앞구르기 공중제비 4자세 (v0.5.0 2b) | 마젠타 제거, 자르기, 크기·기준점 정렬 |
| `review/v0.6.0/sheets/obstacles*.png`, `items_hearts.png`, `review/v0.6.0/cut/` | 2026-11-08 | Codex 내장 이미지 생성 (요청문: ASSET_PROMPTS.md) | v0.6.0 장애물·아이템·하트 시안 (게임에 포함 안 됨) | `cut/`은 마젠타 배경을 지우고 잘라 냄 (`tools/cut_parts.py`) |
| `assets/raw/obstacles_noribbon.png` → `assets/sprites/obstacles/*.png` | 2026-11-08 | Codex 내장 이미지 생성 (기존 시안과 소품을 `--image`로 첨부, 요청문: ASSET_PROMPTS.md) | 장애물 4종: 화분 무리, 낡은 실외기, 물탱크 탑, 비둘기 떼 | `tools/make_obstacle_art.py`로 마젠타 배경을 지우고 잘라 게임 크기의 2배로 줄임 |
| `assets/sprites/items/snack.png`, `gold.png`, `yarn.png`, `cookie.png`, `can.png`, `bell.png` | 2026-11-09 | `review/v0.6.0/sheets/items_hearts.png`에서 잘라 냄 (요청문: ASSET_PROMPTS.md) | v0.6.0 아이템: 짜먹는 간식(질주), 황금 생선, 털실, 하트 쿠키, 통조림, 금빛 방울 | `tools/make_obstacle_art.py`로 게임 크기의 2배로 줄이고 가장자리 분홍 정리 |
| `assets/sprites/hud/heart_*.png` | 2026-11-08 | `review/v0.6.0/sheets/items_hearts.png`에서 잘라 냄 | 하트 HUD (가득, 금 간, 빈 하트) | 108x92로 줄임 |
| `assets/sprites/buildings/prop_soft_*.png` | 2026-11-08 | 위 건물 소품 원본 | 물러나 보이는 옥상 소품 (굴뚝, 안테나, 난간) | `tools/make_obstacle_art.py`로 채도 55% |
| `review/v0.6.0/mockup_*.png` | 2026-11-08 | v0.5.0 게임 캡처 + 위 시안 + 기존 고양이·생선 그림 | 30초 장면 시안 (게임에 포함 안 됨) | `make_mockups.py`로 합성, 글자는 Gaegu Bold |

## 검토용 음악 후보 (게임에 포함되지 않음, v0.5.0 2b)

사용자가 듣고 고르기 위한 30초 발췌입니다. 고른 곡만 나중에 게임에 넣으며, 그때 "게임에 포함된 것"으로 옮깁니다. CC0 전문은 `review/v0.5.0/2b/music/CC0_LICENSE.txt`.

| 이름 | 만든 사람 | 라이선스 | 출처 | 쓰는 곳 | 수정 |
|---|---|---|---|---|---|
| Happy Clappy Loop | OwlishMedia | CC0 (2026-11-08 공식 페이지에서 확인) | https://opengameart.org/content/happy-clappy-loop | `review/v0.5.0/2b/music/3_cc0_happy_clappy_loop.ogg` | 30초로 이어 붙임, 음량 맞춤, 끝 페이드, ogg 변환 |
| Upbeat song | Ruhinre | CC0 (2026-11-08 공식 페이지에서 확인) | https://opengameart.org/content/upbeat-song | `review/v0.5.0/2b/music/4_cc0_upbeat_song.ogg` | 30초로 자름, 음량 맞춤, 끝 페이드, ogg 변환 |

## 직접 만든 것

- 메뉴 효과음 8종 `assets/audio/sfx/buy·booster_buy·booster_on·no_money·claim·rank_up·swap·page.wav` (강화 사기, 부스터 사기, 부스터 켜기, 생선 부족, 미션 받기, 등급 오름, 바꾸기, 화면 넘김): 2026-11-12, `tools/make_sfx.py`(numpy)로 직접 합성. 외부 음원·샘플 없음. 생선 소리와 같은 -17dB로 틂
- 효과음 17종 `assets/audio/sfx/*.wav` (점프, 더블점프, 착지, 생선, 황금·아이템, 보잉, 퍼펙트, 떨어짐, 속도 단계 오름, 비둘기 구구, 팡, 방울 딸랑, 콤보 띵, 콤보 끊김 툭, 부딪힘 퉁, 심장 두근, 질주 슝): 2026-11-09, 뒤 5종 2026-11-10, `tools/make_sfx.py`(numpy)로 직접 합성. 외부 음원·샘플 없음. 콤보 음계는 같은 생선 소리를 게임 안에서 빠르기만 바꿔 냄
- 음악 후보 `review/v0.5.0/2b/music/1_mochi_walk.ogg`, `2_waddle_swing.ogg`: 2026-11-08, `tools/make_music.py`(numpy)로 직접 작곡·합성. 외부 음원·샘플 없음 (검토용, 게임에 포함 안 됨)
- 안개 크림색 판 `assets/sprites/backdrop/mist_mid_cream.png`, `mist_near_cream.png`: 2026-11-08, `tools/tint_mist.py`로 기존 AI 안개 그림의 색을 45% 섞음 (원본은 그대로 둠)
- 검토 캡처 `review/v0.5.0/2b/*.gif`, `*.png`: 게임 화면을 캡처해 만듦 (영상 비교 이미지는 저장소에 넣지 않음)
- 검토용 비교 그림 `review/v0.4.1/before_*.png`, `after_*.png`, `before_seed7_*.png`, `font_compare.png`, `pole_compare.png`, `compare_sheet.png`, `compare_after.png`, `play_30s.gif`: 2026-11-08, 게임 캡처와 기존 그림으로 직접 합성 (게임에 포함 안 됨). `font_compare.png`의 글꼴(Gaegu, Gamja Flower, Poor Story, 모두 SIL OFL 1.1, google/fonts 커밋 86aced9)은 비교 그림에만 쓰고 저장소에는 넣지 않음
- 프로젝트 아이콘 `icon.svg`: 이 프로젝트에서 직접 만듦
- 안개 설정 M2·M3 판 `assets/sprites/backdrop/mist_far_m2.png`, `mist_mid_m2.png`, `mist_near_m2.png`, `mist_far_m3.png`, `mist_mid_m3.png`, `mist_near_m3.png`: 2026-11-08, `tools/tint_mist.py`로 기존 AI 안개 그림의 색을 섞음 (M2 크림 75%, M3 채도 낮은 크림·옅은 하늘색 90%, 원본은 그대로 둠). v0.5.0부터 게임은 M2만 쓴다
- 배경 음악 `assets/audio/mochi_walk.ogg` "찹쌀떡 산책": 2026-11-08, `tools/make_music.py mochi_game`(numpy)으로 직접 작곡·합성한 곡 (118BPM, 마림바·손뼉·쉐이커, 57초 루프). 외부 음원·샘플을 쓰지 않았고 시드가 같으면 같은 곡이 나옴. 이 프로젝트에서 직접 만듦
- 질주 북 층 `assets/audio/mochi_dash_drums.ogg`: 2026-11-10, `tools/make_music.py mochi_game drums`(numpy)로 직접 합성 (찹쌀떡 산책과 같은 118BPM·같은 길이, 북·잔북·손뼉). 외부 음원·샘플 없음. 이 프로젝트에서 직접 만듦
- 이전 배경 음악 `assets/audio/neighborhood.ogg` (v0.4.x, 지금은 쓰지 않고 보관): 2026-11-08, `tools/make_music.py`(numpy)로 직접 합성한 곡 (C-Am-F-G, 96BPM, 40초 루프). 외부 음원·샘플을 쓰지 않았고 시드가 같으면 같은 곡이 나옴. 이 프로젝트에서 직접 만듦
