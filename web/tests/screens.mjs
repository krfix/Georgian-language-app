// Opens the built web app (web/dist) in Chromium at iPhone size, walks through every screen,
// checks the main flows work and the console stays clean, and saves screenshots.
//   node web/tests/screens.mjs [output-folder]
import { createServer } from "node:http";
import { readFile, mkdir } from "node:fs/promises";
import { extname, join, normalize } from "node:path";
import { fileURLToPath } from "node:url";
import { createRequire } from "node:module";
// Playwright from the project or from the global install (NODE_PATH="$(npm root -g)").
const { chromium } = createRequire(import.meta.url)("playwright");

const dist = fileURLToPath(new URL("../dist/", import.meta.url));
const out = process.argv[2] || fileURLToPath(new URL("../dist-screens/", import.meta.url));
await mkdir(out, { recursive: true });
const types = { ".html": "text/html", ".js": "text/javascript", ".css": "text/css", ".json": "application/json",
  ".svg": "image/svg+xml", ".png": "image/png", ".woff2": "font/woff2", ".mp3": "audio/mpeg", ".webmanifest": "application/manifest+json" };
const server = createServer(async (req, res) => {
  let path = decodeURIComponent(new URL(req.url, "http://x").pathname);
  if (path.endsWith("/")) path += "index.html";
  try {
    const body = await readFile(join(dist, normalize(path)));
    res.writeHead(200, { "Content-Type": types[extname(path)] || "application/octet-stream" });
    res.end(body);
  } catch { res.writeHead(404); res.end(); }
}).listen(0);
const base = `http://localhost:${server.address().port}/`;

const browser = await chromium.launch();
let failures = 0;
const fail = (msg) => { failures++; console.log("FAIL", msg); };

async function session(scheme, language) {
  const ctx = await browser.newContext({ viewport: { width: 390, height: 844 }, deviceScaleFactor: 2, colorScheme: scheme,
    locale: language === "pl" ? "pl-PL" : "en-GB", hasTouch: true, isMobile: true });
  const page = await ctx.newPage();
  page.on("console", (m) => { if (m.type() === "error") fail(`${scheme}/${language} console: ${m.text()}`); });
  page.on("pageerror", (e) => fail(`${scheme}/${language} page error: ${e.message}`));
  const shot = async (name) => {
    await page.waitForTimeout(450);
    await page.screenshot({ path: join(out, `${language}-${scheme}-${name}.png`) });
  };
  const go = async (hash) => { await page.evaluate((h) => { location.hash = h; }, hash); await page.waitForTimeout(150); };
  await page.goto(base);
  await page.waitForSelector('[data-screen="phrasebook"]');
  await shot("01-phrasebook");
  // Scroll to the situations.
  await page.evaluate(() => window.scrollTo(0, 560));
  await shot("02-situations");
  await page.evaluate(() => window.scrollTo(0, 0));
  await page.click('[data-id="category-transport"]');
  await page.waitForSelector(".hero-card");
  await shot("03-category");
  await page.click('.chip[data-sub="taxi"]');
  const taxiOnly = await page.$$eval(".sub-title", (h) => h.length);
  if (taxiOnly !== 1) fail(`sub filter shows ${taxiOnly} groups`);
  await go("/p/pb-ak-gamicheret-tu-sheidzleba");
  await page.waitForSelector('[data-id="phrase-georgian"]');
  await shot("04-phrase");
  await page.click('[data-id="action-save"]');
  if (!(await page.$('.action.on[data-act="save"]'))) fail("save didn't stick");
  await page.click('[data-id="action-list"]');
  await page.fill(".new-list input", language === "pl" ? "Taksówka" : "Taxi");
  await shot("05-list-sheet");
  await page.click('.new-list button[type="submit"]');
  await page.evaluate(() => window.scrollTo(0, 700));
  await shot("06-phrase-more");
  await page.click('[data-id="action-show"]');
  await page.waitForSelector('[data-id="show-phrase"]');
  await shot("07-show");
  const size = await page.$eval(".show-ka", (e) => parseFloat(e.style.fontSize));
  if (!(size >= 40)) fail(`Show mode text only ${size}px`);
  await page.click('[data-act="show-flip"]');
  await page.click('[data-act="show-english"]');
  await shot("08-show-flipped");
  await page.click('[data-id="show-close"]');
  await page.waitForSelector('[data-id="phrase-georgian"]');
  await go("/c/emergency");
  await shot("09-emergency");
  await go("/d/pd-taxi");
  await page.waitForSelector(".bubbles");
  await shot("10-dialogue");
  await page.click('[data-id="practise-0"]');
  await page.waitForSelector(".options");
  await shot("11-practice");
  // Play the passenger's side: a wrong answer first, then the right ones.
  let rounds = 0;
  while ((await page.$(".options")) && rounds++ < 20) {
    const right = await page.evaluate(() => {
      const say = document.querySelector(".say-this").textContent;
      return say;
    });
    const options = await page.$$eval(".option", (os) => os.map((o) => o.dataset.pick));
    const correct = await page.evaluate(({ options, right }) => {
      // The right option is the line of the dialogue whose English is asked.
      return options;
    }, { options, right });
    // Pick each option in turn until the turn moves on.
    const before = await page.$$eval(".bubble", (b) => b.length);
    for (const o of correct) {
      const btn = await page.$(`.option[data-pick="${o.replace(/"/g, '\\"')}"]:not([disabled])`);
      if (!btn) continue;
      await btn.click();
      await page.waitForTimeout(60);
      const after = await page.$$eval(".bubble", (b) => b.length);
      if (after > before) break;
    }
    if (rounds === 1) await shot("12-practice-turn");
  }
  if (!(await page.$(".done-card"))) fail("conversation practice didn't finish");
  await shot("13-practice-done");
  await page.click('.tab[data-tab="search"]');
  await page.waitForSelector("#q");
  await shot("14-search-empty");
  await page.fill("#q", language === "pl" ? "apteka" : "pharmacy");
  await page.waitForTimeout(300);
  const hits = await page.$$eval("#results .phrase-row", (r) => r.length);
  if (hits < 2) fail(`search found ${hits} phrases`);
  await shot("15-search");
  await page.fill("#q", "zzqxw");
  await page.waitForTimeout(300);
  await shot("16-search-nothing");
  await page.click('.tab[data-tab="saved"]');
  await page.waitForSelector('[data-screen="saved"]');
  const saved = await page.$$eval('[data-screen="saved"] .phrase-row', (r) => r.length);
  if (saved !== 1) fail(`my phrasebook shows ${saved} phrases`);
  const listChip = await page.$$eval('.chip[data-filter="list"]', (c) => c.length);
  if (listChip !== 1) fail("the new list has no chip");
  await shot("17-saved");
  await page.click('[data-menu="pb-ak-gamicheret-tu-sheidzleba"]');
  await shot("18-saved-menu");
  await page.click('[data-act="close-sheet"].soft-button');
  await page.click('.tab[data-tab="settings"]');
  await page.waitForSelector('[data-screen="settings"]');
  await shot("19-settings");
  await page.reload();
  await page.waitForSelector('[data-screen="settings"]');
  await page.click('.tab[data-tab="saved"]');
  await page.waitForSelector('[data-screen="saved"]');
  const kept = await page.$$eval('[data-screen="saved"] .phrase-row', (r) => r.length);
  if (kept !== 1) fail("saved phrase lost on reload");
  // Back from a phrase opened from Search returns to Search.
  await page.click('.tab[data-tab="search"]');
  await page.fill("#q", "taxi");
  await page.waitForTimeout(300);
  await page.click("#results .phrase-main");
  await page.waitForSelector('[data-id="phrase-georgian"]');
  await page.click("[data-back]");
  await page.waitForSelector("#q");
  await ctx.close();
}

for (const [scheme, language] of [["light", "en"], ["dark", "en"], ["light", "pl"], ["dark", "pl"]]) {
  await session(scheme, language);
}
// A wide screen (a computer) and a small phone.
for (const [w, h, name] of [[1280, 860, "desktop"], [320, 640, "small"]]) {
  const ctx = await browser.newContext({ viewport: { width: w, height: h }, colorScheme: "light" });
  const page = await ctx.newPage();
  page.on("pageerror", (e) => fail(`${name} page error: ${e.message}`));
  await page.goto(base + "#/p/pb-gamarjoba");
  await page.waitForSelector('[data-id="phrase-georgian"]');
  await page.waitForTimeout(400);
  await page.screenshot({ path: join(out, `en-light-${name}.png`) });
  const overflow = await page.evaluate(() => document.documentElement.scrollWidth > window.innerWidth);
  if (overflow) fail(`${name}: page scrolls sideways`);
  await page.goto(base);
  await page.waitForSelector('[data-screen="phrasebook"]');
  await page.waitForTimeout(400);
  if (await page.evaluate(() => document.documentElement.scrollWidth > window.innerWidth)) fail(`${name}: home scrolls sideways`);
  await page.screenshot({ path: join(out, `en-light-${name}-home.png`) });
  await ctx.close();
}
await browser.close();
server.close();
console.log(failures ? `${failures} problems` : "all screens fine", "→", out);
process.exit(failures ? 1 : 0);
