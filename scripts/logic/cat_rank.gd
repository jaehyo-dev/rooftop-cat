class_name CatRank
extends RefCounted
## 고냥이 등급 (화면과 분리된 로직, review/v0.7.0/PLAN.md 6번). 경험치는 미션에서만 들어온다.
## 저장의 rank.level(1~10)·rank.xp(지금 등급 안에서 모은 경험치). 마지막 등급 뒤에는 RANK_AFTER_MAX_XP마다 생선.


## 다음 등급(마지막 등급이면 다음 보너스)까지 필요한 경험치
static func next_xp(level: int) -> int:
	var table := MissionTable.RANK_NEXT_XP
	return table[level - 1] if level <= table.size() else MissionTable.RANK_AFTER_MAX_XP


static func rank_name(level: int) -> String:
	return MissionTable.RANK_NAMES[clampi(level, 1, MissionTable.RANK_NAMES.size()) - 1]


## 경험치를 더하고 오른 만큼 보너스(생선·부스터)를 지갑에 넣는다 (저장은 부른 쪽이 함).
## 한 번에 여러 등급이 올라도 빠짐없이 들어간다. 돌려줌: 오른 것마다 {"level", "fish", "boosters"} (마지막 등급 뒤 보너스는 level이 그대로)
static func add_xp(data: Dictionary, xp: int) -> Array:
	var rank: Dictionary = data.rank
	var ups := []
	rank.xp += maxi(xp, 0)
	while rank.xp >= next_xp(rank.level):
		rank.xp -= next_xp(rank.level)
		var up := {"level": rank.level, "fish": MissionTable.RANK_AFTER_MAX_FISH, "boosters": []}
		if rank.level <= MissionTable.RANK_NEXT_XP.size():
			rank.level += 1
			var bonus: Array = MissionTable.RANK_BONUS[rank.level - 2]
			up = {"level": rank.level, "fish": bonus[0], "boosters": bonus[1]}
		data.wallet.fish += up.fish
		for kind: String in up.boosters:
			data.boosters[kind] = mini(data.boosters[kind] + 1, Balance.BOOSTER_MAX)
		ups.append(up)
	return ups
