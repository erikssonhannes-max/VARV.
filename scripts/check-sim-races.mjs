// VARV. – kontrollerar data/sim-races.json innan den publiceras. Kör: node scripts/check-sim-races.mjs
import { readFileSync } from "node:fs";
const d = JSON.parse(readFileSync(new URL("../data/sim-races.json", import.meta.url), "utf8"));
const err = [], seen = new Set();
const MAX = { title: 80, organizer: 80, city: 60, country: 40, venue: 120, price: 40, info: 600 };
const isDay = (s) => typeof s === "string" && /^\d{4}-\d{2}-\d{2}$/.test(s) && !isNaN(Date.parse(s + "T12:00:00Z")) && new Date(s + "T12:00:00Z").toISOString().slice(0, 10) === s;
if (!isDay(d.updated) || !Array.isArray(d.races)) err.push("updated eller races saknas");
for (const r of d.races || []) {
  const n = r.key || JSON.stringify(r).slice(0, 40);
  if (!/^\d{4}-\d{2}-\d{2}-[a-z0-9-]{1,60}$/.test(r.key || "")) err.push(`${n}: ogiltig key`);
  if (seen.has(r.key)) err.push(`${n}: dubblett`);
  seen.add(r.key);
  if (!isDay(r.day)) err.push(`${n}: ogiltigt datum`);
  if (r.key && r.day && !r.key.startsWith(r.day + "-")) err.push(`${n}: key ska börja med datumet`);
  for (const k of ["title", "city", "country"]) if (!r[k]) err.push(`${n}: ${k} saknas`);
  for (const [k, m] of Object.entries(MAX)) if (r[k] != null && (typeof r[k] !== "string" || r[k].length > m)) err.push(`${n}: ${k} ska vara text på högst ${m} tecken`);
  if (r.start_time != null && !/^\d{2}:\d{2}$/.test(r.start_time)) err.push(`${n}: ogiltig start_time`);
  for (const k of ["url", "source"]) if (!/^https:\/\/\S{1,290}$/.test(r[k] || "")) err.push(`${n}: ${k} ska vara en https-länk`);
  if (!isDay(r.checked)) err.push(`${n}: checked saknas`);
}
if (err.length) { console.error(err.join("\n")); process.exit(1); }
console.log(`OK: ${d.races.length} race`);
