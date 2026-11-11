"""v0.7.0 생선 경제 계산 (설계용, 게임 코드 아님).
봇 측정값(economy_result*.md, 시드 30)으로 하루 5판씩 플레이할 때 영구 강화 60단계를 다 사는 날을 계산한다.
실행: python3 review/v0.7.0/economy_calc.py
"""

# 봇 한 판 생선 평균: [강화 0단계, 강화 10단계] (economy_result.md / economy_result_max.md)
FISH = {"초보": (799, 873), "익숙함": (2750, 3192), "숙련": (7434, 7689)}
# 플레이어 모습: 날짜별 실력 (앞 며칠은 초보, 그 뒤 익숙함 등)
PLAYERS = {
    "초보 그대로": lambda day: "초보",
    "보통 (2일 초보 → 익숙함)": lambda day: "초보" if day <= 2 else "익숙함",
    "숙련": lambda day: "숙련",
}
RUNS_PER_DAY = 5
DRAFT = [300, 500, 700, 900, 1100, 1400, 1700, 2000, 2400, 2800]
PROPOSED = [300, 800, 1500, 2200, 2900, 3600, 4400, 5200, 6000, 6800]
UPGRADES = 6
# 미션 수입 (5번 표): 일일 3개 평균 보상 합, 주간 3개 합(7일에 나눔), 등급 보너스 하루 평균. 초보는 일일 2개·주간 2개만 깬다고 본다
MISSION_DAY = {"초보": 1000 + 6000 / 7 + 300, "익숙함": 1500 + 9000 / 7 + 400, "숙련": 1500 + 9000 / 7 + 400}
BOOSTER_DAY = 900  # 부스터에 쓰는 생선 (하루 평균 약 2개)


def simulate(player, prices, days=60):
    levels = [0] * UPGRADES
    wallet, earned_runs, earned_missions = 0, 0, 0
    for day in range(1, days + 1):
        skill = player(day)
        base, top = FISH[skill]
        for _ in range(RUNS_PER_DAY):
            owned = sum(levels) / (UPGRADES * 10)  # 강화를 산 만큼 수입이 0단계 → 10단계 값으로 늘어남
            run = base + (top - base) * owned
            wallet += run
            earned_runs += run
        wallet += MISSION_DAY[skill] - BOOSTER_DAY
        earned_missions += MISSION_DAY[skill]
        # 가장 싼 다음 단계부터 산다
        while True:
            options = [(prices[lv], i) for i, lv in enumerate(levels) if lv < 10]
            if not options:
                return day, earned_missions / (earned_runs + earned_missions)
            cost, i = min(options)
            if cost > wallet:
                break
            wallet -= cost
            levels[i] += 1
    return None, earned_missions / (earned_runs + earned_missions)


def main():
    print("| 플레이어 | 초안 가격 (항목 %s, 전체 %s) | 제안 가격 (항목 %s, 전체 %s) | 미션 비율(제안) |" % (
        f"{sum(DRAFT):,}", f"{sum(DRAFT) * UPGRADES:,}", f"{sum(PROPOSED):,}", f"{sum(PROPOSED) * UPGRADES:,}"))
    print("|---|---|---|---|")
    for name, player in PLAYERS.items():
        d1, _ = simulate(player, DRAFT)
        d2, share = simulate(player, PROPOSED)
        print(f"| {name} | {d1}일 | {d2 if d2 else '60일+'}일 | {share:.0%} |")


if __name__ == "__main__":
    main()
