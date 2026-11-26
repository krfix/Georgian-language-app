// Taps an answer in a lesson and samples how visible the screen is over the next frames.
// A flicker shows up as opacity dipping below 1 or the content shifting.
import { createServer } from "node:http";
import { readFile } from "node:fs/promises";
import { extname, join, normalize } from "node:path";
import { fileURLToPath } from "node:url";
import { createRequire } from "node:module";
const { chromium } = createRequire(import.meta.url)("playwright");
const dist = fileURLToPath(new URL("../dist/", import.meta.url));
const types = { ".html": "text/html", ".js": "text/javascript", ".css": "text/css", ".json": "application/json", ".svg": "image/svg+xml" };
const server = createServer(async (req, res) => {
  let p = decodeURIComponent(new URL(req.url, "http://x").pathname); if (p.endsWith("/")) p += "index.html";
  try { const b = await readFile(join(dist, normalize(p))); res.writeHead(200, { "Content-Type": types[extname(p)] || "application/octet-stream" }); res.end(b); } catch { res.writeHead(404); res.end(); }
}).listen(0);
const browser = await chromium.launch();
const page = await (await browser.newContext({ viewport: { width: 390, height: 844 }, hasTouch: true, isMobile: true })).newPage();
await page.goto(`http://localhost:${server.address().port}/`);
await page.waitForSelector('[data-screen="welcome"]');
for (let i = 0; i < 7; i++) { if (i === 6) await page.fill("#ob-name", "Lena"); await page.click('[data-id="onboarding-next"]'); }
await page.click('[data-id="onboarding-start-lesson"]');
await page.waitForSelector('[data-screen="lesson"]');
for (let n = 0; n < 60 && !(await page.$(".options")); n++) await page.click('[data-act="next"]');
await page.waitForTimeout(500);
const sample = () => page.evaluate(() => new Promise((done) => {
  const out = []; const t0 = performance.now();
  const tick = () => {
    const els = [...document.querySelectorAll(window.PROBE || ".player-body, .player-bottom, .fb-icon")];
    out.push(Math.min(1, ...els.map((e) => +getComputedStyle(e).opacity * (getComputedStyle(e).transform === "none" ? 1 : 0.999))).toFixed(3));
    if (performance.now() - t0 < 350) requestAnimationFrame(tick); else done(out.join(" ")); };
  tick(); }));
let worst = 1;
for (const [label, act] of [["tap option", () => page.click('[data-id="option-0"]')], ["tap other option", () => page.click('[data-id="option-1"]')], ["check", async () => { await page.evaluate(() => { window.PROBE = ".player-body"; }); await page.click('[data-act="check"]'); }]]) {
  await act(); const s = await sample(); console.log(label.padEnd(18), s);
  worst = Math.min(worst, ...s.split(" ").map(Number)); await page.waitForTimeout(400);
}
console.log(worst < 1 ? `FLICKER: the screen faded to ${worst}` : "OK: no fade on tap");
await browser.close(); server.close();
process.exit(worst < 1 ? 1 : 0);
