// 웹 확인 (2b 수정2): 로컬 빌드에서 노을빛 A·B·C 버튼이 보이고, 버튼을 눌러도 점프하지 않고, 약 3초 뒤 시험용 질주가 나오는지 캡처. 콘솔 오류 없음
// 사용: PLAYWRIGHT=<playwright 경로> CHROMIUM=<크로미움> node web_dev_tune_check.mjs <build/web> <출력 폴더>
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
  for (const [name, vp, mobile] of [["pc_1280x720", { width: 1280, height: 720 }, false], ["phone_844x390", { width: 844, height: 390 }, true]]) {
    const ctx = await browser.newContext({ viewport: vp, isMobile: mobile, hasTouch: mobile, deviceScaleFactor: mobile ? 2 : 1 });
    const page = await ctx.newPage();
    const errors = [];
    page.on("console", (m) => { if (m.type() === "error") errors.push(m.text()); });
    page.on("pageerror", (e) => errors.push(String(e)));
    await page.goto(url);
    await page.waitForTimeout(1500);
    // 왼쪽 아래 B 버튼 자리를 누른다 (버튼 줄: "노을빛" A B C)
    const b = mobile ? { x: 24 + 62 * 0.66 + 40, y: vp.height - 22 } : { x: 16 + 95 + 64 + 28, y: vp.height - 40 };
    if (mobile) await page.touchscreen.tap(b.x, b.y); else await page.mouse.click(b.x, b.y);
    await page.waitForTimeout(150);
    await page.screenshot({ path: `${out}/web_${name}_button.png` });
    await page.waitForTimeout(3600);
    await page.screenshot({ path: `${out}/web_${name}_quick_dash.png` });
    console.log(name, errors.length ? `콘솔 오류: ${errors.join(" | ")}` : "콘솔 오류 없음");
    if (errors.length) code = 1;
    await ctx.close();
  }
} finally {
  await browser.close();
  server.close();
}
process.exit(code);
