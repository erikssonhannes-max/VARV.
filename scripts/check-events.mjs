// VARV. – kontrollerar data/events.json innan den publiceras. Kör: node scripts/check-events.mjs
import { readFileSync } from "node:fs";
const d = JSON.parse(readFileSync(new URL("../data/events.json", import.meta.url), "utf8"));
const err = [], seen = new Set(), same = new Set();
const MAX = { city: 60, country: 60, venue: 120, url: 300 };
const isDay = (s) => typeof s === "string" && /^\d{4}-\d{2}-\d{2}$/.test(s) && !isNaN(Date.parse(s + "T12:00:00Z")) && new Date(s + "T12:00:00Z").toISOString().slice(0, 10) === s;
if (!isDay(d.updated) || !Array.isArray(d.events)) err.push("updated eller events saknas");
for (const e of d.events || []) {
  const n = e.key || JSON.stringify(e).slice(0, 40);
  if (!/^\d{4}-\d{2}-\d{2}-[a-z0-9-]{1,60}$/.test(e.key || "")) err.push(`${n}: ogiltig key`);
  if (seen.has(e.key)) err.push(`${n}: dubblett`);
  seen.add(e.key);
  if (!isDay(e.starts) || !isDay(e.ends)) err.push(`${n}: ogiltigt datum`);
  else if (e.ends < e.starts) err.push(`${n}: ends före starts`);
  if (e.key && e.starts && !e.key.startsWith(e.starts + "-")) err.push(`${n}: key ska börja med starts`);
  const twin = `${(e.city || "").toLowerCase()}|${e.starts}`;
  if (same.has(twin)) err.push(`${n}: samma stad och startdag finns redan`);
  same.add(twin);
  for (const k of ["city", "country"]) if (!e[k]) err.push(`${n}: ${k} saknas`);
  if (!["norden", "europa", "varlden"].includes(e.region)) err.push(`${n}: region ska vara norden, europa eller varlden`);
  if (e.kind != null && !["pre", "vm"].includes(e.kind)) err.push(`${n}: kind ska vara pre, vm eller null`);
  for (const [k, m] of Object.entries(MAX)) if (e[k] != null && (typeof e[k] !== "string" || e[k].length > m)) err.push(`${n}: ${k} ska vara text på högst ${m} tecken`);
  if (e.url != null && !/^https:\/\/\S{1,290}$/.test(e.url)) err.push(`${n}: url ska vara en https-länk`);
  if (!/^https:\/\/\S{1,290}$/.test(e.source || "")) err.push(`${n}: source ska vara en https-länk`);
  if (!isDay(e.checked)) err.push(`${n}: checked saknas`);
}
if (err.length) { console.error(err.join("\n")); process.exit(1); }
console.log(`OK: ${d.events.length} tävlingar`);
