#!/usr/bin/env python3
"""v0.6.0 설계 점검 계산기 (게임 코드가 아니라 설계 근거용).

scripts/balance.gd, jump_model.gd의 수치·식을 옮겨 다음을 계산한다:
  1) 속도 단계별 도달 거리·미리 보는 시간
  2) 장애물별로 "언제 누르면 피하는가" 창(ms). 톡은 실제 손처럼 50~100ms 누름
  3) 구간(segments.json)을 사람처럼 통과할 수 있는가: 위험마다 누름 창이 100ms 이상(가운데서 ±50ms 흔들려도 통과),
     누름 길이가 흔들려도 통과, 착지 깊이(0.3~0.87초)가 달라도 통과. 만든 뒤 다음 속도 단계로 달려도 통과.
  4) segments.png: 구간 그림 (점선 = 계획대로 달린 경로)

실행: python3 review/v0.6.0/design_check.py   (실패가 있으면 종료 코드 1)
shortcut: 옥상·장애물 판정만 옮긴 근사이고 실제 RunnerSim이 아니다. 전봇대·트램펄린·코요테·구제는 없다.
          탭 50~100ms는 가정(휴대폰에서 2a에 잰다). 2a에서 GDScript + RunnerSim으로 다시 만든다.
"""
import json
import math
import sys
from multiprocessing import Pool
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

G = 3200.0
V0 = math.sqrt(2 * G * 70.0)  # JumpModel.jump_speed: 0ms 누름의 높이 70
HOLD_MAX = (250.0 - 70.0) / V0
DHOLD_MAX = (130.0 - 70.0) / V0
APEX = HOLD_MAX + V0 / G
FLOAT_V, FLOAT_G = 160.0, 0.5
CAT_W, CAT_H = 150.0, 92.0
FOOT = CAT_W * 0.3
# 장애물 판정용 고양이 타원: 실제 몸의 80% (억울하지 않게 그림보다 작게)
HIT_A, HIT_B = CAT_W * 0.5 * 0.8, CAT_H * 0.5 * 0.8
VIEW_PC, VIEW_PHONE = 1280.0 - 340.0, 1558.0 - 340.0
DT = 1.0 / 60.0
GROW = 8.0        # 구간 검사 때 장애물 판정을 이만큼 넓힘
WINDOW_MIN = 100  # ms: 가운데서 ±50ms 흔들려도 통과
DEPTHS = (0.3, 0.6, 0.87)  # 구간 첫 옥상에 내려앉는 깊이(초). 최대 점프 체공만큼
HERE = Path(__file__).parent
ROOT = HERE.parent.parent

STAGES = [  # 단계, 시작(초), 속도, 구간 밀도(길이에 곱함: 작을수록 촘촘). PLAN 13번 표
    (1, 0, 430, 1.00), (2, 14, 500, 0.97), (3, 28, 570, 0.94), (4, 45, 640, 0.91), (5, 68, 710, 0.88),
    (6, 95, 780, 0.85), (7, 125, 850, 0.82), (8, 160, 910, 0.79), (9, 200, 950, 0.77), (10, 260, 950, 0.73),
    (11, 360, 950, 0.69), (12, 480, 950, 0.65),
]
OBST = {  # 판정 상자: 폭, 아래, 위 (옥상 바닥에서 위로). 비둘기는 초당 FLOCK_V로 다가온다
    "pot":   {"w": 48.0,  "y0": 0.0,   "y1": 38.0,  "name": "화분", "color": (200, 96, 60)},
    "ac":    {"w": 110.0, "y0": 0.0,   "y1": 88.0,  "name": "실외기", "color": (120, 130, 140)},
    "tank":  {"w": 84.0,  "y0": 0.0,   "y1": 260.0, "name": "물탱크", "color": (150, 80, 90)},
    "flock": {"w": 150.0, "y0": 240.0, "y1": 310.0, "name": "비둘기", "color": (90, 110, 170)},
}
FLOCK_V = 120.0
ACTIONS = {  # 이름: [(누름 길이, 더블 누르는 시각)...] 흔들린 경우 전부 통과해야 안전
    "톡": [(0.05, None), (0.10, None)],
    "중간": [(0.13, None), (0.18, None)],
    "길게": [(HOLD_MAX, None)],
    "더블": [(HOLD_MAX, APEX - 0.05), (HOLD_MAX, APEX + 0.05)],
}


def hit(cx, feet, ox0, ox1, oy0, oy1, grow=0.0):
    cy = feet + CAT_H * 0.5
    nx = min(max(cx, ox0 - grow), ox1 + grow)
    ny = min(max(cy, oy0 - grow), oy1 + grow)
    return ((nx - cx) / HIT_A) ** 2 + ((ny - cy) / HIT_B) ** 2 < 1.0


def advance(y, vy, floating):
    g = G * FLOAT_G if floating and abs(vy) < FLOAT_V else G
    return y + vy * DT - 0.5 * g * DT * DT, vy - g * DT


def air_time(rise=0.0):
    """최대 점프로 높이 차 rise에 내려앉을 때까지 (JumpModel.max_air_time)."""
    return HOLD_MAX + V0 / G + math.sqrt(2 * max(0.0, 250.0 - rise) / G)


def build(seg, v, density=1.0):
    """초로 적은 구간을 속도 v의 거리로 펼친다. density는 첫 장애물 뒤의 간격에 곱한다 (입구 여유·틈·장애물 크기는 그대로)."""
    roofs, obs, items = [], [], []
    x, top = 0.0, 0.0
    for r in seg["roofs"]:
        rise = r.get("rise", 0.0)
        x += r.get("gap", 0.0) * v * air_time(rise)
        top += rise
        # 옥상의 첫 장애물까지(입구 여유)는 줄이지 않는다: 착지 뒤 판단·누름 시간이 필요. 그 뒤 간격만 밀도로 줄인다
        lead = min((at for _, at in r.get("obs", [])), default=1.4)  # 빈 옥상도 1.4초까지는 줄이지 않음
        squeeze = lambda at, lead=lead: at if at <= lead else lead + (at - lead) * density
        left, right = x, x + squeeze(r["t"]) * v
        roofs.append((left, right, top))
        for kind, at in r.get("obs", []):
            o = OBST[kind]
            obs.append({"kind": kind, "x": left + squeeze(at) * v, "w": o["w"], "y0": top + o["y0"], "y1": top + o["y1"],
                        "moves": kind == "flock"})
        for it in r.get("items", []):
            items.append({"kind": it[0], "x": left + squeeze(it[1]) * v, "y": top + it[2], "n": it[3] if len(it) > 3 else 1})
        x = right
    return roofs, obs, items


def obstacle_hit(obs, cx, y, v, grow):
    for o in obs:
        x0 = o["x"]
        if o["moves"]:
            # 비둘기 위치는 고양이 x의 함수: 고양이 가운데가 o["x"]에 올 때 그 자리에서 만난다 (생성 시각과 무관, 겹침 유지)
            x0 = o["x"] - FLOCK_V * (cx - o["x"]) / v
        if hit(cx, y, x0, x0 + o["w"], o["y0"], o["y1"], grow):
            return o
    return None


def flight(world, x, top, hold, dj, v):
    """(x, top)에서 뛰어 착지까지. 반환 (착지 x, 착지 높이, 경로) 또는 None(맞음·떨어짐·벽)."""
    roofs, obs = world
    y, vy, t, used, dj_end, path = top, V0, 0.0, False, 0.0, []
    lowest = min(r[2] for r in roofs) - 160.0
    while True:
        x += v * DT
        if t < hold:
            y, vy = y + V0 * DT, V0
        elif dj is not None and not used and t >= dj:
            used, vy, dj_end = True, V0, t + DHOLD_MAX
            y += V0 * DT
        elif used and t < dj_end:
            y, vy = y + V0 * DT, V0
        else:
            prev = y
            y, vy = advance(y, vy, used)
            for l, r, rt in roofs:
                if vy < 0 and prev >= rt >= y and x + FOOT >= l and x - FOOT <= r:
                    return x, rt, path
        t += DT
        path.append((x, y))
        if y < lowest or obstacle_hit(obs, x, y, v, GROW):
            return None
        for l, r, rt in roofs:  # 옥상 벽에 닿으면 실패로 친다 (투명화 구제 없이 통과해야 공정)
            if rt > y + 0.5 and l <= x + CAT_W / 2 and x - CAT_W / 2 <= r:
                return None


def ground_hazard(world, x, top, v, end):
    """땅에서 그대로 달릴 때 첫 위험. (위험 x, 지나야 할 x) 또는 None(끝까지 안전)."""
    roofs, obs = world
    here = next((r for r in roofs if r[2] == top and r[0] - FOOT <= x <= r[1] + FOOT), None)
    limit = min(here[1] + FOOT, end) if here else x
    cx = x
    while cx < limit:
        cx += v * DT * 2
        o = obstacle_hit(obs, cx, top, v, GROW)
        if o:
            return cx, o["x"] + o["w"] + HIT_A + GROW
        for r in roofs:  # 앞 옥상 벽
            if r[2] > top + 0.5 and r[0] <= cx + CAT_W / 2 and cx - CAT_W / 2 <= r[1]:
                return cx, r[0] + FOOT
    return None if cx >= end else (limit, limit)


def plan(seg, v, density=1.0, depth=0.6, run_v=None, need_gold=False):
    """위험을 차례로 넘는 사람 계획. {"ok", "min_window", "min_react", "path", "actions", "why"}"""
    run_v = run_v or v
    roofs, obs, items = build(seg, v, density)
    world = (roofs, obs)
    gold = [i for i in items if i["kind"] == "gold"] if need_gold else []
    end = roofs[-1][1] - 0.2 * v
    x, top = roofs[0][0] + depth * run_v, roofs[0][2]
    res = {"ok": False, "min_window": 9999, "min_react": 99.0, "path": [], "actions": [], "why": ""}
    for _ in range(12):
        hz = ground_hazard(world, x, top, run_v, end)
        if hz is None:
            res["path"].extend((px, top) for px in frange(x, end, run_v * DT * 3))
            res["ok"] = True
            return res
        xh, clear = hz
        best = None
        for name, variants in ACTIONS.items():
            # 위험 앞 1.4초 안에서, 위험 직전까지 누름 시점을 훑어 가장 긴 연속 창을 찾는다
            n = int(min((xh - x) / run_v, 1.4) * 30)
            run, runs = [], []
            for k in range(n + 1):
                px = xh - k / 30 * run_v
                land = None
                for hold, dj in variants:
                    land = flight(world, px, top, hold, dj, run_v)
                    if land is None or land[0] <= clear:
                        land = None
                        break
                    if gold and clear >= gold[0]["x"] and not collects(land[2], gold[0]):
                        land = None
                        break
                if land:
                    run.append(px)
                else:
                    if run:
                        runs.append(run)
                    run = []
            if run:
                runs.append(run)
            for r in runs:
                ms = (len(r) - 1) * 1000 // 30
                if best is None or ms > best[0]:
                    best = (ms, name, r[len(r) // 2], variants)
            # 사람은 간단한 동작부터 쓴다: 창이 충분한 가장 간단한 동작을 고름 (ACTIONS는 간단한 순서)
            if best is not None and best[0] >= WINDOW_MIN:
                break
        if best is None or best[0] < WINDOW_MIN:
            res["why"] = f"x={xh:.0f}: 가장 넓은 창 {best[0] if best else 0}ms"
            return res
        ms, name, press_x, variants = best
        hold, dj = variants[0] if len(variants) == 1 else (sum(a[0] for a in variants) / 2, variants[0][1] and APEX)
        land = flight(world, press_x, top, hold, dj, run_v)
        if land is None:
            res["why"] = f"x={press_x:.0f}: 가운데 입력 실패"
            return res
        res["path"].extend((px, top) for px in frange(x, press_x, run_v * DT * 3))
        res["path"].extend(land[2][::2])
        res["min_window"] = min(res["min_window"], ms)
        res["actions"].append(name)
        react = (xh - x) / run_v  # 앞 착지(또는 시작) 뒤 위험까지 시간: 판단할 수 있는 여유
        res["min_react"] = min(res["min_react"], react)
        if gold and collects(land[2], gold[0]):
            gold = []
        x, top = land[0], land[1]
    res["why"] = "위험이 너무 많음"
    return res


def collects(path, g):
    return any(((px - g["x"]) / (CAT_W / 2 + 24)) ** 2 + ((py + CAT_H / 2 - g["y"]) / (CAT_H / 2 + 24)) ** 2 < 1 for px, py in path)


def frange(a, b, step):
    out = []
    while a < b:
        out.append(a)
        a += step
    return out


def windows(kind, speed):
    """동작별로 맞지 않고 지나가는 누름 시점의 창(ms)과, 정답으로 피할 때 가장 늦은 누름(초 전)."""
    o = OBST[kind]
    roofs = [(-5000.0, 9000.0, 0.0)]
    obs = [{"kind": kind, "x": 0.0, "w": o["w"], "y0": o["y0"], "y1": o["y1"], "moves": kind == "flock"}]
    world = (roofs, obs)
    out, latest = {}, {}
    for name, variants in ACTIONS.items():
        ok = 0
        for i in range(450):
            lead = i * 0.005
            px = -lead * speed
            safe = not obstacle_hit(obs, px, 0.0, speed, 0.0)
            for hold, dj in variants:
                land = flight(world, px, 0.0, hold, dj, speed) if safe else None
                if land is None or (o["y0"] < 90 and land[0] <= o["w"] + HIT_A):
                    safe = False
            ok += safe
            if safe and name not in latest:
                latest[name] = lead
        out[name] = ok * 5
    return out, latest


def self_check():
    """탐색기가 진짜로 구별하는지: 못 건너는 것은 못 건넌다고 해야 한다."""
    assert not plan({"roofs": [{"t": 2.0}, {"gap": 2.4, "t": 2.0}]}, 430.0)["ok"], "더블로도 못 건너는 틈을 통과함"
    assert plan({"roofs": [{"t": 2.0}, {"gap": 1.2, "t": 2.0}]}, 430.0)["ok"], "더블로 건너는 틈을 못 통과함"
    assert windows("tank", 430.0)[0]["길게"] == 0, "물탱크가 한 번 점프로 넘어감"
    assert windows("ac", 430.0)[0]["톡"] == 0, "처음 속도에서 실외기가 톡으로 넘어감"
    assert not hit(0.0, 0.0, -50.0, 50.0, OBST["flock"]["y0"], OBST["flock"]["y1"]), "비둘기가 달리기에 맞음"
    assert plan({"roofs": [{"t": 3.8, "obs": [["tank", 2.0]]}]}, 570.0)["actions"] == ["더블"], "물탱크 정답이 더블이 아님"


def check_seg(seg):
    """구간 하나를 모든 단계·깊이로 검사. (행, 실패 목록)"""
    row, bad, worst_w, worst_r = [], [], 9999, 99.0
    stages = [s for s in STAGES if s[2] >= seg["min_speed"]]
    has_gold = any(it[0] == "gold" for r in seg["roofs"] for it in r.get("items", []))
    for s in STAGES:
        if s[2] < seg["min_speed"]:
            row.append("·")
            continue
        ok = True
        for depth in DEPTHS:
            p = plan(seg, s[2], s[3], depth)
            if not p["ok"]:
                ok = False
                bad.append(f"{seg['id']} 단계{s[0]} 깊이{depth}: {p['why']}")
                break
            worst_w, worst_r = min(worst_w, p["min_window"]), min(worst_r, p["min_react"])
        row.append("O" if ok else "X")
    for a, b in zip(stages, stages[1:]):
        if a[2] != b[2]:
            p = plan(seg, a[2], a[3], 0.6, run_v=b[2])
            if not p["ok"]:
                bad.append(f"{seg['id']} 만든 속도 {a[2]} > 달림 {b[2]}: {p['why']}")
    gold = ""
    if has_gold:
        fails = [s[2] for s in stages if not plan(seg, s[2], s[3], 0.6, need_gold=True)["ok"]]
        gold = "O" if not fails else "못 먹음: " + ",".join(map(str, fails))
    return seg, row, bad, worst_w, worst_r, gold


def draw(data, out):
    font_path = str(ROOT / "assets/fonts/Gaegu/Gaegu-Bold.ttf")
    font, small = ImageFont.truetype(font_path, 26), ImageFont.truetype(font_path, 19)
    segs = data["segments"]
    colors = {"쉬움": (120, 170, 110), "보통": (225, 165, 70), "어려움": (205, 85, 70)}
    item_c = {"fish": (110, 150, 190), "gold": (235, 180, 40), "slot": (190, 90, 200)}
    w, h = 800, 380
    sc = (w - 36) / max(build(g, g["min_speed"])[0][-1][1] for g in segs)
    img = Image.new("RGB", (w * 2 + 30, (h + 10) * ((len(segs) + 1) // 2) + 80), (250, 243, 232))
    d = ImageDraw.Draw(img)
    d.text((20, 18), "구간 설계 (처음 나오는 속도 기준, 상자 = 판정 크기, 점선 = 사람 입력 계획의 경로)", fill=(90, 60, 40), font=font)
    for n, seg in enumerate(segs):
        ox, oy = 10 + (n % 2) * (w + 10), 70 + (n // 2) * (h + 10)
        v = float(seg["min_speed"])
        roofs, obs, items = build(seg, v)
        has_gold = any(i["kind"] == "gold" for i in items)
        p = plan(seg, v, need_gold=has_gold)
        d.rectangle((ox, oy, ox + w, oy + h), fill=(255, 251, 243), outline=colors[seg["level"]], width=3)
        d.text((ox + 12, oy + 8), f"{seg['id']} {seg['name']} [{seg['level']}] 속도 {seg['min_speed']}부터", fill=colors[seg["level"]], font=font)
        d.text((ox + 12, oy + 38), seg["note"] + "  / 입력: " + ", ".join(p["actions"] or ["그대로 달리기"]), fill=(110, 90, 70), font=small)
        base = oy + h - 50
        sx = lambda x: ox + 18 + x * sc
        sy = lambda y: base - y * 0.56
        for l, r, top in roofs:
            d.rectangle((sx(l), sy(top), sx(r), oy + h - 3), fill=(232, 208, 170), outline=(120, 85, 55), width=2)
        for o in obs:
            c = OBST[o["kind"]]["color"]
            d.rectangle((sx(o["x"]), sy(o["y1"]), sx(o["x"] + o["w"]), sy(o["y0"])), fill=c, outline=(70, 40, 30), width=2)
            d.text((sx(o["x"]) - 4, sy(o["y1"]) - 22), OBST[o["kind"]]["name"] + (" (날아옴)" if o["moves"] else ""), fill=c, font=small)
        for it in items:
            for i in range(it["n"]):
                ix, iy = sx(it["x"] + i * 70.0), sy(it["y"])
                r = 7 if it["kind"] == "fish" else 11
                d.ellipse((ix - r, iy - r, ix + r, iy + r), fill=item_c[it["kind"]], outline=(70, 50, 30))
                if it["kind"] != "fish":
                    d.text((ix + 13, iy - 11), "황금" if it["kind"] == "gold" else "아이템 자리", fill=item_c[it["kind"]], font=small)
        for px, py in p["path"]:
            d.ellipse((sx(px) - 2, sy(py + CAT_H / 2) - 2, sx(px) + 2, sy(py + CAT_H / 2) + 2), fill=(240, 120, 40))
    img.save(out)


def main():
    self_check()
    data = json.loads((HERE / "segments.json").read_text())
    fail = 0
    print("## 1. 속도 단계별 거리·시간\n")
    print("| 단계 | 시작 | 속도 | 구간 밀도 | 한 번 점프 거리 | PC 미리 보는 시간 | 휴대폰 |")
    print("|---|---|---|---|---|---|---|")
    at = air_time()
    for s, t, v, den in STAGES:
        print(f"| {s} | {t}초 | {v} | {den:.2f} | {v * at:.0f} | {VIEW_PC / v:.2f}초 | {VIEW_PHONE / v:.2f}초 |")

    print("\n## 2. 장애물별 누름 창 (ms). 누름 길이가 흔들려도 맞지 않는 시점의 폭. 톡 = 50~100ms 누름\n")
    print("| 장애물 | 속도 | 톡 | 중간 | 길게 | 더블(꼭대기 ±50ms) | 정답 창 | PC 판단 시간 |")
    print("|---|---|---|---|---|---|---|---|")
    answers = {"pot": ["톡", "중간"], "ac": ["중간", "길게"], "tank": ["더블"], "flock": ["톡", "더블"]}
    for kind in OBST:
        for v in (430, 570, 640, 850, 950):
            w, latest = windows(kind, v)
            a = max(answers[kind], key=lambda n: w[n])
            vrel = v + (FLOCK_V if kind == "flock" else 0.0)
            think = VIEW_PC / vrel - latest.get(a, 0.0)
            print(f"| {OBST[kind]['name']} | {v} | {w['톡']} | {w['중간']} | {w['길게']} | {w['더블']} | {a} {w[a]} | {think:.2f}초 |")
            # 물탱크는 단계 3(570)부터 나온다 (430의 95ms는 그래서 괜찮음)
            if (w[a] < WINDOW_MIN or think < 0.35) and not (kind == "tank" and v < 570):
                print(f"경고: {kind} @ {v}: 창 {w[a]}ms, 판단 {think:.2f}초", file=sys.stderr)
                fail += 1

    print(f"\n## 3. 구간 사람 통과 검사 (누름 창 {WINDOW_MIN}ms 이상 = ±50ms 흔들려도 통과, 누름 길이 흔들림, 착지 깊이 {DEPTHS}, 판정 {GROW:.0f}px 넓힘)\n")
    print("| 구간 | 난이도 | " + " | ".join(f"{s[0]}" for s in STAGES) + " | 가장 좁은 창 | 가장 짧은 판단 | 황금 생선 |")
    print("|---|---|" + "---|" * len(STAGES) + "---|---|---|")
    with Pool() as pool:
        results = pool.map(check_seg, data["segments"])
    bads = []
    for seg, row, bad, ww, wr, gold in results:
        print(f"| {seg['id']} {seg['name']} | {seg['level']} | " + " | ".join(row) + f" | {ww}ms | {wr:.2f}초 | {gold} |")
        bads += bad
        fail += len(bad) + (1 if gold.startswith("못") else 0)
    print("\n막힌 조합: " + ("없음" if not bads else "\n- " + "\n- ".join(bads)))
    draw(data, HERE / "segments.png")
    print("\n실패 수:", fail)
    return 1 if fail else 0


if __name__ == "__main__":
    sys.exit(main())
