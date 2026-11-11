// 웹 음악 재현 검사: 진짜 브라우저에서 곡이 한 바퀴 돈 뒤에도 재생 속도가 단계에 맞는지 잰다 (실패하면 종료 코드 1).
// Godot 웹은 곡이 끝나면 새 재생 소스를 만들면서 빠르기를 1.0으로 되돌린다. headless 자동 테스트로는 볼 수 없어 따로 둔다.
// 준비: 곡이 시작된 뒤(1.5초) World.sim.elapsed = 30.0으로 단계 3을 만드는 스크립트를 autoload로 잠깐 넣어 웹으로 내보내고(project.godot은 되돌림), 그 폴더를 넘긴다.
// 곡 길이만큼(약 1분) 걸린다.
// 사용: PLAYWRIGHT=<playwright 폴더> CHROMIUM=<브라우저 실행 파일, 선택> node tools/web_music_check.mjs <내보낸 폴더> [단계 빠르기, 기본 1.026]
// WSL: 창이 뜨지 않게 가상 화면에서만 돈다 (~/Documents/GitHub/DESKTOP_NOTES.md)
//   env -u WAYLAND_DISPLAY xvfb-run -a -s "-screen 0 1280x720x24" node tools/web_music_check.mjs <내보낸 폴더>
import { createRequire } from "node:module";
import { createServer } from "node:http";
import { readFile } from "node:fs/promises";
import { extname, join } from "node:path";
import { release } from "node:os";

const { chromium } = createRequire(import.meta.url)(process.env.PLAYWRIGHT ?? "playwright");
const dir = process.argv[2];
const expected = Number(process.argv[3] ?? 1.026);
const TYPES = { ".html": "text/html", ".js": "text/javascript", ".wasm": "application/wasm" };

const server = createServer(async (req, res) => {
	try {
		const url = new URL(req.url, "http://x").pathname;
		const path = url === "/" ? "/index.html" : url;
		const body = await readFile(join(dir, path));
		res.writeHead(200, { "Content-Type": TYPES[extname(path)] ?? "application/octet-stream" });
		res.end(body);
	} catch {
		res.writeHead(404);
		res.end();
	}
});
await new Promise((ok) => server.listen(0, "127.0.0.1", ok));
// WSL은 headless면 WebGL이 소프트웨어 렌더링이라, Xvfb 가상 화면 + d3d12로 GPU를 쓴다 (맥은 그대로).
// 실제 화면(WSLg)에 창을 띄우지 않도록 xvfb-run 밖에서는 멈춘다
const wsl = process.platform === "linux" && /microsoft/i.test(release());
if (wsl && (process.env.WAYLAND_DISPLAY || process.env.DISPLAY === ":0")) {
	console.error('WSL에서는 창 없이 실행: env -u WAYLAND_DISPLAY xvfb-run -a -s "-screen 0 1280x720x24" node tools/web_music_check.mjs ...');
	process.exit(1);
}
const args = ["--autoplay-policy=no-user-gesture-required"];
const browser = await chromium.launch(wsl
	? { executablePath: process.env.CHROMIUM, headless: false, args: [...args, "--ozone-platform=x11", "--ignore-gpu-blocklist", "--enable-gpu", "--use-angle=gl"], env: { ...process.env, GALLIUM_DRIVER: "d3d12" } }
	: { executablePath: process.env.CHROMIUM, args });
let code = 1;
try {
	const page = await browser.newPage();
	// 긴 곡을 재생하는 소스만 모아 둔다 (효과음은 1초 안팎)
	await page.addInitScript(() => {
		window.__music = [];
		const start = AudioBufferSourceNode.prototype.start;
		AudioBufferSourceNode.prototype.start = function (...args) {
			if (this.buffer && this.buffer.duration > 20) window.__music.push(this);
			return start.apply(this, args);
		};
	});
	await page.goto(`http://127.0.0.1:${server.address().port}/`);
	const read = () => page.evaluate(() => ({ sources: window.__music.length, rate: window.__music.at(-1)?.playbackRate.value, length: window.__music.at(-1)?.buffer.duration }));
	await page.waitForFunction(() => window.__music?.length > 0, null, { timeout: 60000 });
	await page.waitForTimeout(4000);
	const before = await read();
	console.log("곡 시작 뒤:", before);
	await page.waitForFunction(() => window.__music.length > 1, null, { timeout: (before.length / expected + 20) * 1000 });
	await page.waitForTimeout(1000);
	const after = await read();
	console.log("한 바퀴 돈 뒤:", after);
	const same = (rate) => Math.abs(rate - expected) < 0.001;
	code = same(before.rate) && same(after.rate) ? 0 : 1;
	console.log(code === 0 ? "통과: 빠르기가 유지됨" : `실패: 빠르기 ${expected}여야 함`);
} finally {
	await browser.close();
	server.close();
}
process.exit(code);
