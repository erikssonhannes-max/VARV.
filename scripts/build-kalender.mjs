// VARV. – bygger den öppna tävlingskalendern på varvtraining.com/tavlingar/ och sitemap.xml
// från data/events.json och data/sim-races.json. Kör: node scripts/build-kalender.mjs
// Körs av de schemalagda uppgifterna efter varje uppdatering av listorna. Ändra inte de byggda filerna för hand.
//
// Varumärke: Hyrox nämns bara för att beskriva loppen. Inga logotyper, bilder eller texter från HYROX,
// och varje sida säger att VARV. är fristående. Anmälan länkas alltid till arrangören.
import { readFileSync, writeFileSync, mkdirSync, rmSync, existsSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const root = dirname(dirname(fileURLToPath(import.meta.url)));
const SITE = "https://varvtraining.com";
// Vart knappen "Öppna VARV." leder. I dag är appen startsidan. När appen finns i App Store och Google Play,
// och varvtraining.com blir en landningssida, byt till butikslänken eller landningssidans nedladdningsdel.
const APP_URL = "/";
const APP_TEXT = "Öppna VARV.";
const read = (p) => JSON.parse(readFileSync(join(root, p), "utf8"));
const evData = read("data/events.json"), simData = read("data/sim-races.json");
const today = process.env.VARV_TODAY || new Date().toLocaleDateString("sv-SE", { timeZone: "Europe/Stockholm" });
const updated = [evData.updated, simData.updated].sort().pop();

const esc = (s) => String(s ?? "").replace(/[&<>"']/g, (c) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" })[c]);
const slug = (s) => String(s).normalize("NFD").replace(/[̀-ͯ]/g, "").toLowerCase().replace(/[^a-z0-9]+/g, "-").replace(/^-|-$/g, "");
const MON = ["jan", "feb", "mars", "apr", "maj", "juni", "juli", "aug", "sep", "okt", "nov", "dec"];
const MONL = ["januari", "februari", "mars", "april", "maj", "juni", "juli", "augusti", "september", "oktober", "november", "december"];
const d = (s) => new Date(s + "T12:00:00Z");
function range(s, e) {
  const a = d(s), b = d(e || s);
  if (!e || s === e) return `${a.getUTCDate()} ${MON[a.getUTCMonth()]} ${a.getUTCFullYear()}`;
  if (a.getUTCMonth() === b.getUTCMonth()) return `${a.getUTCDate()}–${b.getUTCDate()} ${MON[b.getUTCMonth()]} ${b.getUTCFullYear()}`;
  return `${a.getUTCDate()} ${MON[a.getUTCMonth()]}–${b.getUTCDate()} ${MON[b.getUTCMonth()]} ${b.getUTCFullYear()}`;
}
const longDate = (s) => { const a = d(s); return `${a.getUTCDate()} ${MONL[a.getUTCMonth()]} ${a.getUTCFullYear()}`; };
const https = (u) => typeof u === "string" && /^https:\/\/\S+$/.test(u) ? u : null;

// ---------- Data ----------
const events = (evData.events || []).filter((e) => e && e.city && e.starts && e.ends >= today)
  .map((e) => ({ type: "tavling", start: e.starts, end: e.ends, title: e.city, city: e.city, country: e.country, region: e.region, venue: e.venue, pre: e.kind === "pre", vm: e.kind === "vm", url: https(e.url) }))
  .sort((a, b) => a.start.localeCompare(b.start) || a.title.localeCompare(b.title, "sv"));
const sims = (simData.races || []).filter((r) => r && r.title && r.day >= today)
  .map((r) => ({ type: "sim", start: r.day, end: r.day, title: r.title, city: r.city, country: r.country, region: "norden", venue: r.venue, organizer: r.organizer, time: r.start_time, price: r.price, url: https(r.url) }))
  .sort((a, b) => a.start.localeCompare(b.start) || a.title.localeCompare(b.title, "sv"));
const all = [...events, ...sims];
const years = [...new Set(all.map((x) => x.start.slice(0, 4)))].sort();
const yearText = years.length > 1 ? `${years[0]}–${years[years.length - 1]}` : years[0] || today.slice(0, 4);

const countries = new Map();
for (const x of all) {
  if (!x.country) continue;
  const k = slug(x.country);
  if (!countries.has(k)) countries.set(k, { name: x.country, slug: k, region: x.region, events: [], sims: [] });
  countries.get(k)[x.type === "sim" ? "sims" : "events"].push(x);
}
const countryList = [...countries.values()].sort((a, b) => a.name.localeCompare(b.name, "sv"));

// ---------- HTML ----------
const CSS = `:root{--bg:#fff;--tile:#f4f4f6;--card:#fff;--ink:#111114;--muted:#6e6e76;--hair:#dcdce1;--link:#e0123f;--accent:#f0124a;--accent2:#ff6a3d;--green:#1fae4b;--cyan:#0aa7c4;
  --hot:linear-gradient(135deg,var(--accent),var(--accent2));--f:-apple-system,BlinkMacSystemFont,"SF Pro Text","Helvetica Neue",Helvetica,Arial,sans-serif}
@media (prefers-color-scheme:dark){:root{--bg:#000;--tile:#141416;--card:#232327;--ink:#f5f5f7;--muted:#9a9aa3;--hair:#2e2e33;--link:#ff4d6d;--accent:#ff2d55;--accent2:#ff7a45;--green:#30d158;--cyan:#32c8e6;color-scheme:dark}}
*{box-sizing:border-box}
body{margin:0;background:var(--bg);color:var(--ink);font:400 17px/1.5 var(--f);letter-spacing:-.015em;-webkit-font-smoothing:antialiased}
.wrap{max-width:760px;margin:0 auto;padding:calc(28px + env(safe-area-inset-top,0px)) max(16px,env(safe-area-inset-right,0px)) calc(56px + env(safe-area-inset-bottom,0px)) max(16px,env(safe-area-inset-left,0px))}
.top{display:flex;justify-content:space-between;align-items:center;gap:12px;margin-bottom:28px}
.brand{display:flex;align-items:center;gap:10px;font-weight:700;color:var(--ink);text-decoration:none}
.brand img{width:30px;height:30px;border-radius:8px}
.top a.x,.back{color:var(--link);text-decoration:none;font-size:15px}
.eyebrow{display:block;font-size:13px;font-weight:600;color:var(--muted);text-transform:uppercase;letter-spacing:.04em}
h1{font-size:clamp(34px,9vw,51px);letter-spacing:-.045em;line-height:1.04;margin:6px 0 10px;font-weight:600;text-wrap:balance}
.lead{color:var(--muted);font-size:17px;margin:0 0 6px;max-width:60ch}
h2{font-size:22px;letter-spacing:-.02em;margin:34px 0 4px;font-weight:600}
h2+.sub{color:var(--muted);font-size:15px;margin:0 0 12px}
.month{font-size:13px;font-weight:600;color:var(--muted);text-transform:uppercase;letter-spacing:.04em;margin:18px 4px 8px}
.group{background:var(--tile);border-radius:20px;overflow:hidden}
.row{display:grid;grid-template-columns:52px 1fr;gap:14px;align-items:center;padding:12px 16px;min-height:64px}
.row+.row{border-top:1px solid var(--hair)}
.badge{width:52px;height:52px;border-radius:12px;background:var(--card);display:flex;flex-direction:column;align-items:center;justify-content:center;line-height:1}
.badge b{font-size:20px;font-weight:700;font-variant-numeric:tabular-nums}
.badge small{font-size:11px;color:var(--muted);margin-top:3px;text-transform:uppercase;letter-spacing:.03em}
.row h3{margin:0;font-size:17px;font-weight:600;letter-spacing:-.02em}
.row p{margin:2px 0 0;font-size:15px;color:var(--muted)}
.row a{color:var(--link);text-decoration:none;font-size:15px}
.tag{display:inline-block;font-size:12px;font-weight:600;border-radius:980px;padding:2px 8px;margin-left:6px;vertical-align:2px;background:var(--card);color:var(--muted)}
.chips{display:flex;flex-wrap:wrap;gap:8px;margin-top:10px}
.chips a{display:inline-flex;align-items:center;min-height:44px;padding:0 16px;border-radius:980px;background:var(--tile);color:var(--ink);text-decoration:none;font-size:15px}
.chips a span{color:var(--muted);margin-left:6px;font-variant-numeric:tabular-nums}
.cta{background:var(--hot);color:#fff;border-radius:20px;padding:22px 20px;margin:34px 0 0}
.cta h2{margin:0 0 6px;color:#fff}
.cta p{margin:0 0 16px;color:rgba(255,255,255,.92);max-width:52ch}
.cta a{display:inline-flex;align-items:center;min-height:44px;padding:0 20px;border-radius:980px;background:#fff;color:#111114;font-weight:600;text-decoration:none}
.empty{background:var(--tile);border-radius:20px;padding:18px 20px;color:var(--muted)}
.foot{font-size:13px;color:var(--muted);margin-top:34px;max-width:65ch}
.foot a{color:var(--muted)}
@media (prefers-reduced-motion:no-preference){.group,.cta{animation:up .55s cubic-bezier(.2,.8,.2,1) both}@keyframes up{from{opacity:0;transform:translateY(14px)}}}`;

function row(x) {
  const a = d(x.start);
  const tags = (x.vm ? '<span class="tag">VM</span>' : "") + (x.pre ? '<span class="tag">Preliminärt</span>' : "");
  const where = x.type === "sim"
    ? [x.organizer, x.venue, x.time, x.price].filter(Boolean).join(" · ")
    : [x.country, x.venue].filter(Boolean).join(" · ");
  const when = range(x.start, x.end);
  const link = x.url ? ` · <a href="${esc(x.url)}" rel="noopener" target="_blank">${x.type === "sim" ? "Anmälan hos arrangören" : "Läs mer hos arrangören"}</a>` : "";
  // Arrangörernas egna namn på simuleringar visas inte, så att de inte kan förväxlas med officiella lopp.
  const name = x.type === "sim" ? `Simulering i ${x.city}` : x.city;
  return `<div class="row"><span class="badge" aria-hidden="true"><b>${a.getUTCDate()}</b><small>${MON[a.getUTCMonth()]}</small></span><div><h3>${esc(name)}${tags}</h3><p>${esc(when)}${where ? " · " + esc(where) : ""}${link}</p></div></div>`;
}
function byMonth(list) {
  const out = []; let cur = null, buf = [];
  const flush = () => { if (buf.length) out.push(`<div class="month">${esc(cur)}</div><div class="group">${buf.join("")}</div>`); buf = []; };
  for (const x of list) {
    const a = d(x.start), m = `${MONL[a.getUTCMonth()]} ${a.getUTCFullYear()}`;
    if (m !== cur) { flush(); cur = m; }
    buf.push(row(x));
  }
  flush();
  return out.join("");
}
const section = (title, sub, list) => list.length ? `<h2>${esc(title)}</h2><p class="sub">${esc(sub)}</p>${byMonth(list)}` : "";
const cta = `<div class="cta"><h2>Träna inför ditt lopp</h2><p>Välj ditt lopp och din måltid i VARV., så lägger appen upp träningen vecka för vecka fram till start.</p><a href="${APP_URL}">${esc(APP_TEXT)}</a></div>`;
const foot = `<p class="foot">Uppgifterna kommer från arrangörernas egna sidor och kontrolleras varje vecka, senast ${esc(longDate(updated))}. Datum och arenor kan ändras, så kontrollera alltid hos arrangören innan du bokar eller reser. Anmälan sker hos arrangören.<br><br>VARV. är fristående och har ingen koppling till HYROX. HYROX är ett registrerat varumärke som tillhör sin ägare. <a href="/legal/villkor.html">Villkor</a> · <a href="/legal/integritet.html">Integritet</a></p>`;

function page({ path, title, desc, eyebrow, h1, lead, back, body }) {
  const url = SITE + path;
  return `<!doctype html>
<html lang="sv">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1,viewport-fit=cover">
<meta http-equiv="Content-Security-Policy" content="default-src 'self'; style-src 'self' 'unsafe-inline'; img-src 'self' data:; script-src 'none'; object-src 'none'; base-uri 'self'">
<title>${esc(title)}</title>
<meta name="description" content="${esc(desc)}">
<link rel="canonical" href="${url}">
<meta name="theme-color" content="#ffffff" media="(prefers-color-scheme: light)">
<meta name="theme-color" content="#000000" media="(prefers-color-scheme: dark)">
<meta property="og:type" content="website">
<meta property="og:site_name" content="VARV.">
<meta property="og:locale" content="sv_SE">
<meta property="og:url" content="${url}">
<meta property="og:title" content="${esc(title)}">
<meta property="og:description" content="${esc(desc)}">
<meta property="og:image" content="${SITE}/icons/varv-og.png">
<meta name="twitter:card" content="summary_large_image">
<link rel="icon" type="image/png" sizes="32x32" href="/icons/varv-32.png">
<link rel="apple-touch-icon" href="/icons/varv-180.png">
<style>${CSS}</style>
</head>
<body><div class="wrap">
<div class="top"><a class="brand" href="/"><img src="/icons/varv-192.png" alt="">VARV.</a><a class="x" href="${APP_URL}">${APP_URL === "/" ? "Till appen" : "Hämta appen"}</a></div>
${back ? `<a class="back" href="${back.href}">${esc(back.text)}</a>` : ""}
<span class="eyebrow">${esc(eyebrow)}</span>
<h1>${esc(h1)}</h1>
<p class="lead">${esc(lead)}</p>
${body}
${cta}
${foot}
</div></body></html>
`;
}

const files = new Map();
const chips = (list) => `<div class="chips">${list.map((c) => `<a href="/tavlingar/${c.slug}/">${esc(c.name)}<span>${c.events.length + c.sims.length}</span></a>`).join("")}</div>`;

// Översikt
const nordenEv = events.filter((e) => e.region === "norden"), europaEv = events.filter((e) => e.region === "europa"), varldEv = events.filter((e) => e.region !== "norden" && e.region !== "europa");
files.set("tavlingar/index.html", page({
  path: "/tavlingar/",
  title: `Hyrox-tävlingar och simuleringar ${yearText} | VARV.`,
  desc: `Kalender över kommande Hyrox-tävlingar i hela världen och simuleringar i Norden ${yearText}, med datum, arena och länk till anmälan. Uppdateras varje vecka.`,
  eyebrow: "Kalender",
  h1: "Tävlingar.",
  lead: `Kommande Hyrox-tävlingar i hela världen och simuleringar i Norden. Listan uppdateras varje vecka.`,
  body: (all.length ? "" : `<p class="empty">Inga kommande lopp just nu.</p>`)
    + (countryList.length ? `<h2>Per land</h2>${chips(countryList)}` : "")
    + section("Simuleringar i Norden", "Lopp i samma format som arrangeras av gym och klubbar. Bra för att testa formen inför tävlingen.", sims)
    + section("Tävlingar i Norden", "Sverige, Norge, Danmark, Finland och Island.", nordenEv)
    + section("Tävlingar i Europa", `${europaEv.length} tävlingar.`, europaEv)
    + section("Tävlingar i resten av världen", `${varldEv.length} tävlingar.`, varldEv),
}));

// En sida per land
for (const c of countryList) {
  const n = c.events.length, s = c.sims.length;
  const what = [n ? `${n} ${n === 1 ? "tävling" : "tävlingar"}` : "", s ? `${s} ${s === 1 ? "simulering" : "simuleringar"}` : ""].filter(Boolean).join(" och ");
  files.set(`tavlingar/${c.slug}/index.html`, page({
    path: `/tavlingar/${c.slug}/`,
    title: `Hyrox-tävlingar i ${c.name} ${yearText} | VARV.`,
    desc: `Kommande Hyrox-tävlingar${s ? " och simuleringar" : ""} i ${c.name}: ${what}, med datum, arena och länk till anmälan.`,
    eyebrow: "Kalender",
    h1: `${c.name}.`,
    lead: `Kommande Hyrox-tävlingar${s ? " och simuleringar" : ""} i ${c.name}.`,
    back: { href: "/tavlingar/", text: "Alla tävlingar" },
    body: section("Tävlingar", n === 1 ? "1 tävling." : `${n} tävlingar.`, c.events) + section("Simuleringar", "Lopp i samma format som arrangeras av gym och klubbar.", c.sims)
      + `<h2>Andra länder</h2>${chips(countryList.filter((o) => o.slug !== c.slug))}`,
  }));
}

// Sitemap
const urls = [["/", updated], ["/tavlingar/", updated], ...countryList.map((c) => [`/tavlingar/${c.slug}/`, updated]), ["/support/", null], ["/legal/villkor.html", null], ["/legal/integritet.html", null]];
files.set("sitemap.xml", `<?xml version="1.0" encoding="UTF-8"?>
<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">
${urls.map(([u, m]) => `  <url><loc>${SITE}${u}</loc>${m ? `<lastmod>${m}</lastmod>` : ""}</url>`).join("\n")}
</urlset>
`);

// Skriv. Landssidor som inte längre har några lopp tas bort.
if (existsSync(join(root, "tavlingar"))) rmSync(join(root, "tavlingar"), { recursive: true, force: true });
for (const [p, html] of files) { mkdirSync(dirname(join(root, p)), { recursive: true }); writeFileSync(join(root, p), html); }
console.log(`OK: kalendern byggd med ${events.length} tävlingar, ${sims.length} simuleringar och ${countryList.length} länder`);
