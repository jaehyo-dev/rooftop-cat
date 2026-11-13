# 프로젝트 규칙

지붕 위의 고냥이: Godot 4 (GDScript)로 만드는 색연필 손그림풍 모바일(가로 화면) 무한 달리기 게임. 게임 설계는 [GAME_SPEC.md](GAME_SPEC.md)를 따른다.

- 공통 규칙은 전역 `~/.claude/CLAUDE.md`를 따른다. 여기에는 이 저장소에만 있는 규칙만 둔다. 전역 파일을 못 읽는 환경(클라우드 세션)은 [docs/CLAUDE_REFERENCE.md](docs/CLAUDE_REFERENCE.md) 1장의 사본을 읽어.
- 보고·로그·커밋 메시지·하위 에이전트 요청과 답·리뷰 결과(Codex 포함)는 모두 한국어로 써.
- 기본 브랜치는 `main`. 저장소 https://github.com/jaehyo-dev/rooftop-cat · 게임 https://jaehyo-dev.github.io/rooftop-cat/

## 단계

- 단계가 끝난다 = 최종 검토 통과 + main 배포. 다음 단계는 내가 "다음"이라고 할 때 시작해.
- 끝난 단계: 0~8 (v0.0.1 준비 ~ v0.7.0 강화 상점·미션). 예전 단계 표는 [참고](docs/CLAUDE_REFERENCE.md#5-예전-단계-표).
- 이후 단계는 GAME_SPEC 로드맵("단계별 진행" 표, "게임 정체성" 절)을 따른다. 버전은 실제 배포 상태가 우선이야.

## 테스트

Godot 4.7.2 (`deploy.yml`의 `GODOT_VERSION`과 같음). 이 맥북: `GODOT=/Users/jaehyo/Downloads/Godot.app/Contents/MacOS/Godot`. 순서대로 실행해 (1을 먼저 해야 2가 `TestCase` 등을 찾음: 새 저장소, `.godot/` 삭제 뒤, 에셋·`class_name` 변경 뒤).

```bash
godot --headless --path . --import                              # 1) 리소스 가져오기
bash tests/run_tests.sh                                         # 2) 게임 테스트 (GODOT=경로 로 바꿀 수 있음)
python3 -m unittest discover -s tools -p "test_*.py" -v         # 3) 도구·버전 테스트
mkdir -p build/web && godot --headless --path . --export-release "Web" "$PWD/build/web/index.html"  # 4) 웹 내보내기
```

- 게임 테스트는 `-s res://tests/run_tests.gd`로 직접 부르지 말고 `tests/run_tests.sh`로 실행해 (이유: [참고](docs/CLAUDE_REFERENCE.md#2-테스트-설명)).
- 로컬은 대표 조합만(약 4분), 전체는 `FULL_TESTS=1 bash tests/run_tests.sh`(약 8분). Actions는 늘 FULL. 새 "모든 조합" 테스트는 `TestCase.pick(목록, n)`이나 `full_tests()`를 써. 테스트 작성법은 [참고](docs/CLAUDE_REFERENCE.md#2-테스트-설명).
- Actions가 모든 브랜치 푸시마다 1~4를 실행해.
- 게임 플레이 수치는 `scripts/balance.gd` 한곳에 (색·여백 같은 꾸밈 값은 각 화면 파일에 둬도 됨). 로직은 화면과 분리해 `scripts/logic/`에 둬.
- GAME_SPEC.md "테스트할 로직"은 그 기능을 만드는 단계에서 자동 테스트로 만들어.
- 화면 확인은 웹 내보내기 결과를 로컬 서버 + Playwright(Chromium)로.
- `review/`의 GIF는 3MB 이하(넘으면 크기·프레임 수를 줄여). 앞으로 `review/`에는 최종 비교 그림과 GIF만 커밋한다.
- PROGRESS.md에는 만든 것, 내가 판단한 것, 검토 결과, 플레이하며 확인할 부분을 적어.
- 최종 검토자는 `.claude/agents/final-reviewer.md`.

## 버전

- 버전 번호는 `project.godot`의 `config/version` 한 곳. CHANGELOG.md와 다르면 `deploy.yml`이 실패하고 태그·배포를 하지 않아.
- 게임이 바뀌지 않는 변경은 버전을 안 올려도 되고, 이때는 배포만 다시 돼.
- 푸시 뒤 워크플로 결과, 릴리스 생성, 게임 주소에서 새 버전이 열리는지 확인하고 보고해.
- Godot 버전을 올릴 때는 `GODOT_VERSION`, `project.godot`의 `config/features`, CREDITS.md를 함께 바꾸고, 이전 버전 태그들도 새 Godot로 빌드되는지 확인해.

## Codex

- codex나 /ponytail-review를 쓸 수 없는 환경이면 건너뛰고 보고에 적어.
- 기본은 Homebrew `codex`. 설치·업데이트 직후 첫 실행은 몇 분 멈출 수 있어 `--version`으로 먼저 깨워. 안 되면 `/Applications/ChatGPT.app/Contents/Resources/codex-cli/bin/codex`.
- 요청문을 `--image`보다 앞에: `codex exec --sandbox read-only "<요청>" --image <기준 그림>`. Bash에서는 끝에 `< /dev/null`을 붙여 (안 붙이면 stdin을 기다리며 멈춤).
- 이미지: 먼저 쓸 수 있는 에셋을 찾고, 어울리는 게 없을 때 Codex의 내장 이미지 생성을 쓴다. 요청 끝에 항상 "내장 이미지 생성 도구만 사용하고, 스크립트를 만들거나 API를 호출하지 마"를 붙여. API 키는 절대 쓰지 마.
- 결과 그림은 "가장 최근 파일" 대신 출력의 `session id` 폴더 `~/.codex/generated_images/<session id>/`에서 가져와 (다른 세션도 그림을 만듦).
- 배경 제거는 `rembg i -m isnet-general-use -a <원본> <결과>` (`~/.local/venvs/rembg`, 기본 모델은 비상업이라 안 씀). 단색 면 그림은 연두 배경을 초록 우세도(G - max(R, B))로 지우고 어두운 배경에서 초록 테두리를 확인해.

## 오픈소스·에셋

- 그림·효과·소리·음악·글꼴·셰이더·애드온·라이브러리는 만들기 전에 먼저 찾고, 어울리면 쓰고, 후보 2~4개를 게임 화면 안 시안으로 사용자에게 보여 준 뒤 확정한다. 이미 만든 것은 갈아엎지 않는다.
- 쓸 수 있음: MIT, BSD, Apache-2.0, zlib, CC0, CC-BY 3.0/4.0, SIL OFL 1.1(글꼴)
- 먼저 물어볼 것: CC-BY-SA, MPL-2.0, LGPL, 그 밖에 목록에 없는 라이선스
- 쓰지 않음: GPL·AGPL(웹 게임 전체 공개 의무), CC-BY-NC, CC-BY-ND, 라이선스 없음·"무료"만·출처 불분명, 다른 게임·영화에서 추출한 것, 상표·캐릭터
- 공식 배포처에서 받고 버전을 고정해. 에셋은 `assets/종류/이름/`에, 라이선스 전문은 옆에 `LICENSE.txt`(또는 원래 이름)로. 배포 때 워크플로가 CREDITS.md, `assets/`의 라이선스 파일, Godot 라이선스를 사이트 `licenses/`에 올려.
- CREDITS.md: 직접 만든 에셋과 Codex AI 그림은 "직접 만든 것"에(요청문은 ASSET_PROMPTS.md), 개발·배포에만 쓰는 도구(GitHub Actions 등)는 아래쪽 표에 적어.

## 프로젝트 파일

- 폴더 구조는 [참고](docs/CLAUDE_REFERENCE.md#3-프로젝트-구조).
- `*.import`, `*.uid`는 커밋하고 `.godot/`, `build/`는 커밋하지 마.
- 웹 내보내기는 Compatibility 렌더러, 스레드 없음 유지 (자동 테스트가 확인).
- 화면은 모바일 가로(1280x720, `stretch/aspect=expand`). 최근접 필터는 쓰지 않아.
- 그림: `assets/raw/`(원본, 내보내기 제외) → `assets/sprites/`(배경 제거, 게임에서 씀). `assets/concept/`는 시안·참고용(내보내기 제외). I·J·K, A~E 시안도 여기 남겨 둬.

## 기준 캐릭터

- 기준 캐릭터는 `assets/concept/cat_reference_sheet.png`, 기준 그림은 `assets/sprites/cat_base_run.png`(1024x1024), 동작 참고는 `assets/concept/poses/`.
- 통통한 치즈 태비, 접힌 귀, 작은 점 눈과 볼 홍조, 색연필 질감, 초록 목도리. 몸 둘레에 얇은 밝은 테두리가 기본.
- 새 고양이 그림은 항상 기준 그림을 `--image`로 넘겨. 배경은 연두 말고 마젠타(#FF00FF).
- 초록 목도리는 모든 스킨·동작에서 유지하고, 스킨은 털 무늬와 색만 바꿔.
- 이미지 생성은 맥북 터미널의 Claude Code에서만 가능 (Codex 로그인이 맥북에만 있음).
