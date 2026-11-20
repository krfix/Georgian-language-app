// Keeps Ara working offline. web/build.py fills in the version and the list of files.
// - The app and its content are kept when a version installs, and served from this device.
// - Audio clips are kept the first time they play (or all at once from Settings), in their own
//   store that survives new versions (a clip's file name changes when its sound does).
// - A new version replaces the old one as soon as it has installed; its files come from the
//   network, never from the browser's own short-term copies (which could be the old ones).

const VERSION = "__VERSION__";
const SHELL = __SHELL__;
const SHELL_CACHE = `ara-shell-${VERSION}`;
const AUDIO_CACHE = "ara-audio";

self.addEventListener("install", (event) => {
  event.waitUntil(caches.open(SHELL_CACHE).then((c) => c.addAll(SHELL.map((u) => new Request(u, { cache: "reload" })))).then(() => self.skipWaiting()));
});

self.addEventListener("activate", (event) => {
  event.waitUntil((async () => {
    for (const key of await caches.keys()) {
      if (key.startsWith("ara-shell-") && key !== SHELL_CACHE) await caches.delete(key);
    }
    await self.clients.claim();
  })());
});

self.addEventListener("fetch", (event) => {
  const req = event.request;
  const url = new URL(req.url);
  if (req.method !== "GET" || url.origin !== location.origin) return;
  if (url.pathname.endsWith(".mp3")) { event.respondWith(clip(req)); return; }
  if (req.mode === "navigate") {
    event.respondWith(caches.match("./", { cacheName: SHELL_CACHE }).then((r) => r || fetch(req)));
    return;
  }
  event.respondWith(caches.match(req, { ignoreSearch: true }).then((r) => r || fetch(req)));
});

// Audio: from this device if kept, otherwise fetched whole and kept. Safari asks for audio in
// byte ranges, so a range is cut from the whole file.
async function clip(req) {
  const cache = await caches.open(AUDIO_CACHE);
  const plainURL = req.url.split("#")[0];
  let res = await cache.match(plainURL);
  if (!res) {
    try {
      const full = await fetch(plainURL);
      if (!full.ok) return full;
      await cache.put(plainURL, full.clone());
      res = full;
    } catch (e) {
      return new Response("", { status: 504 });
    }
  }
  const range = req.headers.get("range");
  if (!range) return res;
  const buf = await res.arrayBuffer();
  const m = /bytes=(\d*)-(\d*)/.exec(range);
  const size = buf.byteLength;
  let start = m && m[1] ? parseInt(m[1], 10) : 0;
  let end = m && m[2] ? parseInt(m[2], 10) : size - 1;
  if (m && !m[1] && m[2]) { start = Math.max(0, size - parseInt(m[2], 10)); end = size - 1; }
  end = Math.min(end, size - 1);
  return new Response(buf.slice(start, end + 1), {
    status: 206,
    headers: {
      "Content-Type": "audio/mpeg",
      "Content-Length": String(end - start + 1),
      "Content-Range": `bytes ${start}-${end}/${size}`,
      "Accept-Ranges": "bytes",
    },
  });
}
