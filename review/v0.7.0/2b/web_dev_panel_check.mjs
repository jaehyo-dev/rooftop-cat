// 웹 확인 (2b): 로컬 빌드의 시험 패널을 펼쳐 미션 줄(+1일·+7일·미션 완료·경험치 +100)과 상태 글(날짜·등급·미션)을 캡처. 콘솔 오류 없음
// 사용: PLAYWRIGHT=<playwright 경로> CHROMIUM=<크로미움> node web_dev_panel_check.mjs <build/web> <출력 폴더>
import { createRequire } from "node:module";
import { createServer } from "node:http";
import { readFile } from "node:fs/promises";
import { extname, join } from "node:path";
const { chromium } = createRequire(import.meta.url)(process.env.PLAYWRIGHT);
const [dir, out] = process.argv.slice(2);
const TYPES = { ".html": "text/html", ".js": "text/javascript", ".wasm": "application/wasm" };
const server = createServer(async (req, res) => {
  try { const p = new URL(req.url, "http://x").pathname; const f = p === "/" ? "/index.html" : p;
    res.writeHead(200, { "Content-Type": TYPES[extname(f)] ?? "application/octet-stream" }); res.end(await readFile(join(dir, f)));
  } catch { res.writeHead(404); res.end(); }
});
await new Promise((ok) => server.listen(0, "127.0.0.1", ok));
const url = `http://127.0.0.1:${server.address().port}/`;
const browser = await chromium.launch({ executablePath: process.env.CHROMIUM });
let code = 0;
try {
  for (const [name, vp, mobile, k] of [["pc_1280x720", { width: 1280, height: 720 }, false, 1], ["phone_844x390", { width: 844, height: 390 }, true, 390 / 720]]) {
    const ctx = await browser.newContext({ viewport: vp, isMobile: mobile, hasTouch: mobile, deviceScaleFactor: mobile ? 2 : 1 });
    const page = await ctx.newPage();
    const errors = [];
    page.on("console", (m) => { if (m.type() === "error") errors.push(m.text()); });
    page.on("pageerror", (e) => errors.push(String(e)));
    await page.goto(url);
    await page.waitForTimeout(2500);
    // 왼쪽 아래 "시험" 버튼 (여백 12 + 버튼 약 70x46, 게임 화면 높이 720 기준)
    const t = { x: (12 + 30) * k, y: vp.height - (12 + 22) * k };
    if (mobile) await page.touchscreen.tap(t.x, t.y); else await page.mouse.click(t.x, t.y);
    await page.waitForTimeout(400);
    await page.screenshot({ path: `${out}/web_${name}_panel.png` });
    console.log(name, errors.length ? `콘솔 오류: ${errors.join(" | ")}` : "콘솔 오류 없음");
    if (errors.length) code = 1;
    await ctx.close();
  }
} finally {
  await browser.close();
  server.close();
}
process.exit(code);
