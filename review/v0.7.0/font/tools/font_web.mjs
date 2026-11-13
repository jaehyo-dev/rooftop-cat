// 글꼴 비교 캡처: 임시 작업 복사본의 검수용 웹 빌드(qa_web.gd에 font 모드를 더한 것)를 헤드리스 Chromium(창 없음)으로 연다.
// 2c-polish/qa_web.mjs를 줄인 것. 사용: PLAYWRIGHT=<playwright> node font_web.mjs <build/qa> <출력 폴더> <gaegu|nsr|jua|gowun> <pc|phone>
// 출력: <출력>/<글꼴>_<size>/<번호_화면>.png, small.json(보조 크기 글자 칸), console.txt. 콘솔 오류가 있으면 종료 코드 1
import { createRequire } from "node:module";
import { createServer } from "node:http";
import { readFile, writeFile, mkdir } from "node:fs/promises";
import { extname, join } from "node:path";
const { chromium } = createRequire(import.meta.url)(process.env.PLAYWRIGHT);
const [dir, outRoot, font, size] = process.argv.slice(2);
const out = join(outRoot, `${font}_${size}`);
const TYPES = { ".html": "text/html", ".js": "text/javascript", ".wasm": "application/wasm" };
const server = createServer(async (req, res) => {
  try { const p = new URL(req.url, "http://x").pathname; const f = p === "/" ? "/index.html" : p;
    res.writeHead(200, { "Content-Type": TYPES[extname(f)] ?? "application/octet-stream" }); res.end(await readFile(join(dir, f)));
  } catch { res.writeHead(404); res.end(); }
});
await new Promise((ok) => server.listen(0, "127.0.0.1", ok));
const vp = size === "phone" ? { width: 844, height: 390 } : { width: 1280, height: 720 };
const browser = await chromium.launch(process.env.CHROME ? { executablePath: process.env.CHROME } : {});
const errors = [], small = {};
try {
  const ctx = await browser.newContext({ viewport: vp, isMobile: size === "phone", hasTouch: size === "phone" });
  const page = await ctx.newPage();
  page.on("console", (m) => { if (m.type() === "error") errors.push(m.text()); });
  page.on("pageerror", (e) => errors.push(String(e)));
  await page.goto(`http://127.0.0.1:${server.address().port}/?qa=font&font=${font}`);
  await mkdir(out, { recursive: true });
  const deadline = Date.now() + 5 * 60 * 1000;
  while (Date.now() < deadline) {
    const s = await page.evaluate(() => ({ shot: window.qaShot, taken: window.qaTaken, small: window.qaSmall, end: !!window.qaEnd }));
    if (s.shot && s.shot.name !== s.taken) {
      await page.screenshot({ path: join(out, `${s.shot.name}.png`) });
      small[s.shot.name] = s.small;
      await page.evaluate((n) => { window.qaTaken = n; }, s.shot.name);
      continue;
    }
    if (s.end) break;
    await page.waitForTimeout(50);
  }
  await writeFile(join(out, "small.json"), JSON.stringify(small));
} finally {
  await writeFile(join(out, "console.txt"), errors.join("\n"));
  await browser.close();
  server.close();
}
console.log(`${font} ${size}: 찍음 ${Object.keys(small).length}, 콘솔 오류 ${errors.length}`);
process.exit(errors.length ? 1 : 0);
