// 줄줄이 시험판 캡처 (2c-juice/qa_web.mjs + 헤드리스 Chrome에 WebGL2가 없어 SwiftShader 켬). 사용은 2c-juice/qa_web.mjs와 같음 (모드 parade / parade_phone)
// 사용: PLAYWRIGHT=<playwright 경로> node qa_web.mjs <build/web> <출력 폴더> shots|gif <look> <pc|phone>
// shots: <출력>/<이름>_<look>_<pc|phone>.png + cells.json(글자 칸, 창 픽셀), gif: <출력>/gif/<이름>/f000.png… + times.json
// 콘솔 오류는 <출력>/console_<mode>_<look>_<size>.txt 에 남기고, 있으면 종료 코드 1
import { createRequire } from "node:module";
import { createServer } from "node:http";
import { readFile, writeFile, mkdir } from "node:fs/promises";
import { extname, join } from "node:path";
const { chromium } = createRequire(import.meta.url)(process.env.PLAYWRIGHT);
const [dir, out, mode, look, size] = process.argv.slice(2);
const TYPES = { ".html": "text/html", ".js": "text/javascript", ".wasm": "application/wasm" };
const server = createServer(async (req, res) => {
  try { const p = new URL(req.url, "http://x").pathname; const f = p === "/" ? "/index.html" : p;
    res.writeHead(200, { "Content-Type": TYPES[extname(f)] ?? "application/octet-stream" }); res.end(await readFile(join(dir, f)));
  } catch { res.writeHead(404); res.end(); }
});
await new Promise((ok) => server.listen(0, "127.0.0.1", ok));
const vp = size === "phone" ? { width: 844, height: 390 } : { width: 1280, height: 720 };
const browser = await chromium.launch({ ...(process.env.CHROME ? { executablePath: process.env.CHROME } : {}), args: ["--use-angle=swiftshader", "--enable-unsafe-swiftshader", "--ignore-gpu-blocklist"] });  // 기본 headless (창 없음). CHROME = 이미 받은 브라우저 경로
const errors = [];
const cells = {};
try {
  const ctx = await browser.newContext({ viewport: vp, isMobile: size === "phone", hasTouch: size === "phone" });
  const page = await ctx.newPage();
  page.on("console", (m) => { if (m.type() === "error") errors.push(m.text()); });
  page.on("pageerror", (e) => errors.push(String(e)));
  await page.goto(`http://127.0.0.1:${server.address().port}/?qa=${mode}&look=${look}`);
  await mkdir(out, { recursive: true });
  const deadline = Date.now() + 25 * 60 * 1000;
  let rec = "", frames = [], t0 = 0;
  while (Date.now() < deadline) {
    const s = await page.evaluate(() => ({ shot: window.qaShot, taken: window.qaTaken, rec: window.qaRec || "", end: !!window.qaEnd }));
    if (s.rec !== rec) {  // GIF 하나 끝 → 시간 기록
      if (rec) await writeFile(join(out, "gif", rec, "times.json"), JSON.stringify(frames));
      rec = s.rec; frames = []; t0 = Date.now();
      if (rec) await mkdir(join(out, "gif", rec), { recursive: true });
    }
    if (rec) {
      await page.screenshot({ path: join(out, "gif", rec, `f${String(frames.length).padStart(3, "0")}.png`) });
      frames.push(Date.now() - t0);
      continue;
    }
    if (s.shot && s.shot.name !== s.taken) {
      const name = `${s.shot.name}_${size}`;
      await page.screenshot({ path: join(out, `${name}.png`) });
      cells[name] = s.shot.cells;
      await page.evaluate((n) => { window.qaTaken = n; }, s.shot.name);
      continue;
    }
    if (s.end) break;
    await page.waitForTimeout(50);
  }
  if (mode === "shots") await writeFile(join(out, `cells_${look}_${size}.json`), JSON.stringify(cells));
} finally {
  await writeFile(join(out, `console_${mode}_${look}_${size}.txt`), errors.join("\n"));
  await browser.close();
  server.close();
}
console.log(`${mode} ${look} ${size}: 찍음 ${Object.keys(cells).length}, 콘솔 오류 ${errors.length}`);
process.exit(errors.length ? 1 : 0);
