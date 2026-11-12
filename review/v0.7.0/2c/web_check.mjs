// 웹 확인 (2c): 로컬 웹 빌드를 PC 1280x720·휴대폰 844x390에서 열어 시작 화면 → [시작] 눌러 판 → 캡처, 콘솔 오류 없음
// 사용: PLAYWRIGHT=<playwright 경로> node web_check.mjs <build/web> <출력 폴더>
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
const browser = await chromium.launch(process.env.CHROME ? { executablePath: process.env.CHROME } : {});  // 기본 headless (창 없음). CHROME = 이미 받은 브라우저 경로(버전이 다를 때)
let code = 0;
try {
  for (const [name, vp, mobile] of [["pc_1280x720", { width: 1280, height: 720 }, false], ["phone_844x390", { width: 844, height: 390 }, true]]) {
    const ctx = await browser.newContext({ viewport: vp, isMobile: mobile, hasTouch: mobile, deviceScaleFactor: mobile ? 2 : 1 });
    const page = await ctx.newPage();
    const errors = [];
    page.on("console", (m) => { if (m.type() === "error") errors.push(m.text()); });
    page.on("pageerror", (e) => errors.push(String(e)));
    await page.goto(url);
    await page.waitForTimeout(4000);
    await page.screenshot({ path: `${out}/web_${name}_start.png` });
    // [시작] 버튼: 오른쪽 카드 가운데쯤 (게임 화면 높이 720 기준 y 약 300, 오른쪽 끝에서 약 230)
    const k = vp.height / 720;
    const t = { x: vp.width - 230 * k, y: 300 * k };
    if (mobile) await page.touchscreen.tap(t.x, t.y); else await page.mouse.click(t.x, t.y);
    await page.waitForTimeout(2500);
    await page.screenshot({ path: `${out}/web_${name}_run.png` });
    console.log(name, errors.length ? `콘솔 오류: ${errors.join(" | ")}` : "콘솔 오류 없음");
    if (errors.length) code = 1;
    await ctx.close();
  }
} finally {
  await browser.close();
  server.close();
}
process.exit(code);
