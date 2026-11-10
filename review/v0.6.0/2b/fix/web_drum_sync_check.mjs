// 웹 확인: 콘솔 오류, PC·폰 캡처, 곡과 질주 북이 한 바퀴 돈 뒤에도 같은 순간에 다시 시작하는지
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
const browser = await chromium.launch({ executablePath: process.env.CHROMIUM, args: ["--autoplay-policy=no-user-gesture-required"] });
let code = 0;
try {
  for (const [name, vp, mobile] of [["pc_1280x720", { width: 1280, height: 720 }, false], ["phone_844x390", { width: 844, height: 390 }, true]]) {
    const ctx = await browser.newContext({ viewport: vp, isMobile: mobile, hasTouch: mobile, deviceScaleFactor: mobile ? 2 : 1 });
    const page = await ctx.newPage();
    const errors = [];
    page.on("console", (m) => { if (m.type() === "error") errors.push(m.text()); });
    page.on("pageerror", (e) => errors.push(String(e)));
    await page.addInitScript(() => {
      window.__long = [];
      const start = AudioBufferSourceNode.prototype.start;
      AudioBufferSourceNode.prototype.start = function (...a) {
        if (this.buffer && this.buffer.duration > 20) window.__long.push({ len: this.buffer.duration, off: a[1] ?? 0, now: this.context.currentTime, src: this });
        return start.apply(this, a);
      };
    });
    await page.goto(url);
    await page.waitForTimeout(7000);
    await page.screenshot({ path: `${out}/web_${name}.png` });
    const sync = async () => page.evaluate(() => window.__long.map((s) => ({ len: s.len.toFixed(3), off: s.off.toFixed(3), now: s.now.toFixed(3), zero: (s.now - s.off).toFixed(3) })));
    console.log(name, "긴 소리:", JSON.stringify(await sync()));
    if (!mobile) {
      await page.waitForTimeout(62000);  // 곡 한 바퀴
      const after = await sync();
      console.log("한 바퀴 뒤:", JSON.stringify(after));
      // 한 바퀴 뒤 새로 만든 두 소스(곡·북)가 같은 순간에 시작해야 한다. 이음매 틈 = 새 시작 - (처음 시작 + 곡 길이)
      const [a, b] = after.slice(-2);
      const gap = Math.abs(a.now - b.now), seam = a.now - after[0].now - Number(after[0].len);
      console.log("한 바퀴 뒤 곡·북 시작 차이", gap.toFixed(4), "초, 이음매 틈", seam.toFixed(3), "초");
      if (after.length !== 4 || gap > 0.005) { console.log("실패"); code = 1; } else console.log("통과");
    }
    console.log(name, "콘솔 오류:", errors.length ? errors : "없음");
    if (errors.length) code = 1;
    await ctx.close();
  }
} finally { await browser.close(); server.close(); }
process.exit(code);
