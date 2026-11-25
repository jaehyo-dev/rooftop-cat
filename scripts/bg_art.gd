class_name BgArt
extends RefCounted
## 배경·건물·장애물·구조물·아이템 그림 고르기: 카툰(기본) ↔ 예전 색연필 (시험 단추 "배경 화풍", 로컬 빌드만).
## 카툰 그림은 예전 파일 자리를 덮어썼고, 예전 그림은 같은 이름으로 "<폴더>_pencil/"에 옮겨 두었다.
## 예전 폴더에 없는 그림(카툰으로 다시 그리지 않은 것: 비둘기 떼·빨래줄·츄르 등)은 두 화풍 모두 원래 폴더 그림을 쓴다.

const STYLES := ["카툰", "예전"]
static var pencil := false  # 시험 단추로 바꿈
static var _cache := {}


## 미리 읽어 둔 카툰 그림 → 지금 화풍 그림 (예전이면 같은 이름의 <폴더>_pencil/ 그림, 없으면 그대로)
static func of(t: Texture2D) -> Texture2D:
	if not pencil:
		return t
	var path := t.resource_path
	if not _cache.has(path):
		var old := path.get_base_dir() + "_pencil/" + path.get_file()
		_cache[path] = load(old) if ResourceLoader.exists(old) else t
	return _cache[path]
