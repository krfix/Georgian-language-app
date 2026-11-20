// A layout audit of the whole web app: opens every screen (and every kind of exercise) at
// several phone widths, in English and Polish, with normal and larger text, and checks that
//   • no text is cut off (an ellipsis, a clipped box or a clamped paragraph),
//   • nothing sticks out past the edge of the screen,
//   • an icon alone in its circle or tile sits in the middle of it,
//   • no two pieces of text overlap.
// It saves a full-page screenshot of every screen at the main width for a person to look at.
//   NODE_PATH="$(npm root -g)" node web/tests/audit.mjs [output-folder] [--quick]
import { createServer } from "node:http";
import { readFile, mkdir } from "node:fs/promises";
import { extname, join, normalize } from "node:path";
import { fileURLToPath } from "node:url";
import { createRequire } from "node:module";
const { chromium } = createRequire(import.meta.url)("playwright");

const dist = fileURLToPath(new URL("../dist/", import.meta.url));
const args = process.argv.slice(2);
const quick = args.includes("--quick");
const out = args.find((a) => !a.startsWith("--")) || fileURLToPath(new URL("../dist-audit/", import.meta.url));
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
const problems = new Map(); // "kind|where|what" → the contexts it appeared in
const note = (ctx, screen, list) => {
  for (const p of list) {
    const key = `${p[0]} | ${screen} | ${p.slice(1).join(" ")}`;
    if (!problems.has(key)) problems.set(key, []);
    problems.get(key).push(ctx);
  }
};

// Runs in the page: everything that looks wrong on the screen as it is now.
function inspect() {
  const W = document.documentElement.clientWidth;
  const found = [];
  const shown = (e) => {
    const r = e.getBoundingClientRect();
    if (r.width < 1 || r.height < 1) return false;
    for (let p = e; p && p !== document.body; p = p.parentElement) {
      const cs = getComputedStyle(p);
      if (cs.visibility === "hidden" || cs.display === "none" || cs.opacity === "0") return false;
    }
    return true;
  };
  const scroller = (e) => {
    for (let p = e.parentElement; p; p = p.parentElement) {
      const o = getComputedStyle(p).overflowX;
      if ((o === "auto" || o === "scroll") && p !== document.documentElement && p !== document.body) return true;
    }
    return false;
  };
  const label = (e) => {
    const cls = typeof e.className === "string" && e.className.trim() ? "." + e.className.trim().split(/\s+/).slice(0, 3).join(".") : "";
    const t = (e.textContent || "").trim().replace(/\s+/g, " ").slice(0, 34);
    return `${e.tagName.toLowerCase()}${cls}${t ? ` "${t}"` : ""}`;
  };
  const ownText = (e) => [...e.childNodes].some((n) => n.nodeType === 3 && n.textContent.trim());
  const roots = [...document.querySelectorAll("#view, .tabbar, .sheet, .toast, .gloss")];
  const all = roots.flatMap((r) => [r, ...r.querySelectorAll("*")]).filter((e) => !e.closest("svg") || e.tagName === "svg");
  const texts = [];
  for (const e of all) {
    if (!shown(e)) continue;
    const cs = getComputedStyle(e);
    const r = e.getBoundingClientRect();
    if (ownText(e)) {
      texts.push(e);
      const clips = cs.overflowX !== "visible" || cs.textOverflow === "ellipsis";
      if (clips && e.scrollWidth > e.clientWidth + 1 && e.tagName !== "INPUT") found.push(["cut", label(e), `${e.scrollWidth}>${e.clientWidth}`]);
      if (cs.webkitLineClamp && cs.webkitLineClamp !== "none" && e.scrollHeight > e.clientHeight + 1) found.push(["clamped", label(e)]);
      if (cs.overflowY !== "visible" && cs.overflowY !== "auto" && e.scrollHeight > e.clientHeight + 2) found.push(["cut-height", label(e)]);
    }
    if (!scroller(e) && !e.closest(".ribbons, canvas") && (r.right > W + 0.5 || r.left < -0.5) && cs.position !== "fixed")
      found.push(["off-screen", label(e), `${Math.round(r.left)}..${Math.round(r.right)} of ${W}`]);
  }
  // An icon alone in a box (a round button, a tile, a badge): it should sit in the middle.
  for (const svg of document.querySelectorAll("svg.icon")) {
    if (!shown(svg)) continue;
    const p = svg.parentElement;
    const kids = [...p.childNodes].filter((n) => (n.nodeType === 1 && shown(n)) || (n.nodeType === 3 && n.textContent.trim()));
    if (kids.length !== 1) continue;
    const pr = p.getBoundingClientRect(), sr = svg.getBoundingClientRect();
    if (pr.width > 120 || pr.height > 120) continue;
    const dx = (pr.left + pr.right) / 2 - (sr.left + sr.right) / 2, dy = (pr.top + pr.bottom) / 2 - (sr.top + sr.bottom) / 2;
    if (Math.abs(dx) > 1.5 || Math.abs(dy) > 1.5) found.push(["off-centre", label(p), `dx ${dx.toFixed(1)} dy ${dy.toFixed(1)}`]);
  }
  // Text on top of other text.
  const boxes = texts.map((e) => {
    const range = document.createRange(); range.selectNodeContents(e);
    return [e, [...range.getClientRects()].filter((r) => r.width > 2 && r.height > 2)];
  });
  for (let i = 0; i < boxes.length; i++) for (let j = i + 1; j < boxes.length; j++) {
    const [a, ra] = boxes[i], [b, rb] = boxes[j];
    if (a.contains(b) || b.contains(a)) continue;
    const fixedA = a.closest(".tabbar, .sheet, .toast, .gloss"), fixedB = b.closest(".tabbar, .sheet, .toast, .gloss");
    if (fixedA !== fixedB) continue;
    let hit = false;
    for (const x of ra) for (const y of rb) {
      const w = Math.min(x.right, y.right) - Math.max(x.left, y.left), h = Math.min(x.bottom, y.bottom) - Math.max(x.top, y.top);
      if (w > 3 && h > 0.3 * Math.min(x.height, y.height)) hit = true; // more than glyph boxes touching
    }
    if (hit) found.push(["overlap", label(a), "with", label(b)]);
  }
  return found;
}

// A learner who has done some of the course: lessons, words in review (some due), saved phrases.
function seed(language, text) {
  const now = Date.now(), dayMs = 864e5;
  const key = (t) => { const d = new Date(t); return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, "0")}-${String(d.getDate()).padStart(2, "0")}`; };
  const completed = {};
  for (const id of ["a1", "a2", "a3", "a4", "a5", "a6", "a7", "a8", "a9", "v1", "v2"]) completed[id] = now - dayMs;
  const m = (due, right = 3, wrong = 0) => ({ ease: 2.5, interval: 3, repetitions: 2, lapses: 0, due, lastSeen: now - 2 * dayMs, right, wrong });
  const mastery = {};
  for (const c of ["ა", "ბ", "გ", "დ", "ე", "ვ", "ზ", "თ", "ი", "კ", "ლ", "მ"]) mastery[`letter-${c}`] = m(now - 1000);
  mastery["w-gamarjoba"] = m(now - 1000, 1, 4);
  mastery["w-madloba"] = m(now + 3 * dayMs);
  const days = {};
  for (let i = 0; i < 4; i++) days[key(now - i * dayMs)] = { xp: 30, answers: 12, correct: 10, lessons: 1, reviewed: 4 };
  return { saved: { "pb-gamarjoba": { list: "Taxi" }, "pb-ak-gamicheret-tu-sheidzleba": { list: "" } }, learned: { "pb-gamarjoba": now },
    recent: ["pb-gamarjoba"], settings: { language, textSize: text, appearance: "system" },
    profile: { onboarded: true, name: "Ana", goal: 20, level: "beginner" }, completed, mastery, days };
}

const screens = [
  ["home", "/"], ["learn", "/learn"], ["alphabet", "/alphabet"], ["review", "/review"], ["progress", "/progress"],
  ["words", "/words"], ["word", "/w/w-gamarjoba"], ["phrasebook", "/phrasebook"], ["category", "/c/transport"],
  ["emergency", "/c/emergency"], ["phrase", "/p/pb-ak-gamicheret-tu-sheidzleba"], ["phrase-short", "/p/pb-gamarjoba"],
  ["show", "/show/pb-ak-gamicheret-tu-sheidzleba"], ["dialogue", "/d/pd-pharmacy"], ["practice", "/d/pd-taxi/as/0"],
  ["search", "/search"], ["saved", "/saved"], ["settings", "/settings"],
];
const lessons = quick ? ["a1", "v3"] : ["a1", "a9", "v3", "g1", "e1", "c1"];

async function run({ language, text, width, scheme, shots }) {
  const ctxName = `${language}/${text}/${width}`;
  const ctx = await browser.newContext({ viewport: { width, height: 844 }, deviceScaleFactor: shots ? 2 : 1, colorScheme: scheme,
    locale: language === "pl" ? "pl-PL" : "en-GB", hasTouch: true, isMobile: true });
  const page = await ctx.newPage();
  page.on("pageerror", (e) => note(ctxName, "page", [["error", e.message]]));
  const tag = `${language}-${text}-${width}`;
  const check = async (name) => {
    await page.waitForTimeout(350);
    note(ctxName, name, await page.evaluate(inspect));
    if (shots) await page.screenshot({ path: join(out, `${tag}-${name}.png`), fullPage: true });
  };
  const go = async (hash) => { await page.evaluate((h) => { location.hash = h; }, hash); await page.waitForTimeout(200); };

  // The welcome steps, from a fresh start.
  await page.addInitScript(([s]) => { try { if (!sessionStorage.getItem("seeded")) { localStorage.setItem("ara.web.v1", JSON.stringify(s)); sessionStorage.setItem("seeded", "1"); } } catch { /* not the app */ } },
    [{ saved: {}, learned: {}, recent: [], settings: { language, textSize: text }, profile: {}, completed: {}, mastery: {}, days: {} }]);
  await page.goto(base);
  await page.waitForSelector('[data-screen="welcome"]');
  for (let i = 0; i < 7; i++) {
    await check(`welcome-${i}`);
    if (i === 6) await page.fill("#ob-name", "Ana");
    await page.click('[data-id="onboarding-next"]');
  }
  await check("welcome-ready");

  // The seeded learner.
  await page.goto("about:blank");
  await page.goto(base + "icons/favicon.svg");
  await page.evaluate((s) => { localStorage.setItem("ara.web.v1", JSON.stringify(s)); }, seed(language, text));
  await page.goto(base + "#/");
  await page.waitForSelector('[data-screen="home"]');
  for (const [name, hash] of screens) {
    await go(hash);
    await check(name);
  }
  // Sheets and bubbles.
  await go("/learn");
  await page.click('.stone-row:has(.stone.current)');
  await page.waitForSelector(".sheet");
  await check("lesson-preview");
  await go("/learn");
  await go("/p/pb-ak-gamicheret-tu-sheidzleba");
  await page.click('[data-id="action-list"]');
  await check("list-sheet");
  await go("/search");
  await page.fill("#q", language === "pl" ? "apteka" : "pharmacy");
  await check("search-results");
  await go("/w/w-gamarjoba");
  const tappable = await page.$(".tap-word, [data-gloss]");
  if (tappable) { await tappable.click(); await check("gloss"); }

  // Lessons: every exercise kind once, a wrong answer's feedback, a right one's, and the end.
  for (const id of lessons) {
    await go(`/lesson/${id}`);
    await page.waitForSelector('[data-screen="lesson"]');
    const seen = new Set();
    for (let n = 0; n < 80 && !(await page.$('[data-screen="complete"]')); n++) {
      const shape = await page.evaluate(() => [["teach", ".teach, .note-card"], ["matching", ".match-grid"], ["tiles", ".tile-bank"], ["typing", "#answer"],
        ["flash", ".flashcard"], ["dialogue", ".bubbles"], ["listen", ".listen-prompt"], ["choice", ".options"]].find(([, s]) => document.querySelector(s))?.[0] || "other");
      if (await page.$(".feedback")) {
        const v = await page.evaluate(() => document.querySelector(".feedback").className);
        const k = /wrong/.test(v) ? "wrong" : /almost/.test(v) ? "almost" : "right";
        if (!seen.has(`fb-${k}`)) { seen.add(`fb-${k}`); await check(`${id}-feedback-${k}`); }
        await page.click('[data-act="next"]'); continue;
      }
      if (!seen.has(shape)) { seen.add(shape); await check(`${id}-${shape}`); }
      if (await page.$('[data-act="next"]') && !(await page.$('[data-act="check"], [data-act="flip"], [data-act="recall"]'))) { await page.click('[data-act="next"]'); continue; }
      if (await page.$(".match-grid")) {
        for (const pid of await page.$$eval('.match[data-match="ka"]:not(.done)', (e) => e.map((x) => x.dataset.pid))) {
          await page.click(`.match[data-match="ka"][data-pid="${pid}"]`); await page.click(`.match[data-match="other"][data-pid="${pid}"]`);
        }
        continue;
      }
      if (await page.$('[data-act="flip"]')) { await page.click('[data-act="flip"]'); if (!seen.has("flash-back")) { seen.add("flash-back"); await check(`${id}-flash-back`); } await page.click('[data-act="recall"][data-value="1"]'); continue; }
      if (await page.$("#answer")) await page.fill("#answer", n % 2 ? "x" : "gamarjoba");
      else if (await page.$(".tile-bank")) await page.click('[data-id="tile-0"]');
      else if (await page.$(".option")) await page.click(`.option >> nth=${n % 2}`);
      const c = await page.$('[data-act="check"]:not([disabled])');
      if (c) await c.click(); else break;
      await page.waitForTimeout(40);
    }
    if (await page.$('[data-screen="complete"]')) await check(`${id}-complete`);
    await go("/learn");
  }
  await ctx.close();
}

const runs = [];
for (const language of ["pl", "en"]) for (const text of ["normal", "large"]) {
  runs.push({ language, text, width: 390, scheme: language === "pl" ? "dark" : "light", shots: true });
  if (!quick) for (const width of [360, 440]) runs.push({ language, text, width, scheme: "dark", shots: false });
}
if (!quick) runs.push({ language: "pl", text: "large", width: 320, scheme: "dark", shots: true });
for (const r of runs) { await run(r); console.log("done", r.language, r.text, r.width); }
await browser.close();
server.close();

const lines = [...problems].sort().map(([k, ctxs]) => `${k}   [${[...new Set(ctxs)].join(", ")}]`);
console.log(lines.join("\n"));
console.log(`${lines.length} problems → ${out}`);
