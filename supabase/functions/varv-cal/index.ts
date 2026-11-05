// VARV. – träningsplanen som kalender att prenumerera på.
// Länken innehåller en hemlig nyckel per användare: …/functions/v1/varv-cal?t=NYCKEL
// Slå av "Enforce JWT verification" för funktionen, annars kan Kalender inte hämta den.
import { createClient } from "npm:@supabase/supabase-js@2";

const SB = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!);

const CORS = { "Access-Control-Allow-Origin": "*" };
const DAY = /^\d{4}-\d{2}-\d{2}$/;
const clean = (v: string | null, n = 120) => (v || "").replace(/[\r\n]+/g, " ").trim().slice(0, n);
const esc = (v: string) => v.replace(/([\\;,])/g, "\\$1").replace(/\n/g, "\\n");
// Rader i en kalenderfil får vara högst 75 tecken. Längre rader fortsätter på nästa rad med ett mellanslag.
const fold = (v: string) => { const out = []; for (let i = 0; i < v.length; i += 60) out.push((i ? " " : "") + v.slice(i, i + 60)); return out.join("\r\n"); };

// Ett enskilt lopp: …/functions/v1/varv-cal?ev=1&c=Stad&n=Land&v=Plats&s=2026-12-10&e=2026-12-13&r=Datum&k=Klass&u=Länk&vm=1
// iPhone visar då Lägg till i Kalender direkt. Inget sparas och ingen inloggning behövs.
function raceIcs(q: URLSearchParams): string | null {
  const c = clean(q.get("c"), 60), s = q.get("s") || "", e = q.get("e") || s;
  if (!c || !DAY.test(s) || !DAY.test(e) || e < s) return null;
  const end = new Date(e + "T12:00:00Z");
  if (isNaN(end.getTime()) || isNaN(new Date(s + "T12:00:00Z").getTime())) return null;
  end.setUTCDate(end.getUTCDate() + 1);
  const d = (x: string) => x.replace(/-/g, "");
  const n = clean(q.get("n"), 60), v = clean(q.get("v")), r = clean(q.get("r"), 60), k = clean(q.get("k"), 60), vm = q.get("vm") === "1";
  const u0 = clean(q.get("u"), 300), u = /^https:\/\/[^\s"<>]+$/.test(u0) ? u0 : "https://hyrox.com";
  const title = `HYROX ${vm ? "Världsmästerskap " : ""}${c}`;
  const place = [v, c, n].filter(Boolean).join(", ");
  const about = [title + (n ? `, ${n}` : ""), v ? `Plats: ${v}` : "", r ? `Datum: ${r}` : "", k ? `Din klass: ${k}` : "", `Anmälan: ${u}`, "Tillagt från VARV."].filter(Boolean).join("\n");
  return ["BEGIN:VCALENDAR", "VERSION:2.0", "PRODID:-//VARV//SV", "METHOD:PUBLISH", "BEGIN:VEVENT",
    `UID:ev-${c.replace(/\W/g, "")}-${s}@varv`, `DTSTAMP:${new Date().toISOString().replace(/[-:]/g, "").slice(0, 15)}Z`,
    `DTSTART;VALUE=DATE:${d(s)}`, `DTEND;VALUE=DATE:${d(end.toISOString().slice(0, 10))}`,
    fold(`SUMMARY:${esc(title)}`), fold(`LOCATION:${esc(place)}`), fold(`DESCRIPTION:${esc(about)}`), fold(`URL:${u}`),
    "TRANSP:TRANSPARENT", "END:VEVENT", "END:VCALENDAR", ""].join("\r\n");
}

Deno.serve(async (req) => {
  const q = new URL(req.url).searchParams;
  if (q.get("ev")) {
    const ics = raceIcs(q);
    if (!ics) return new Response("Saknas", { status: 400, headers: CORS });
    return new Response(ics, { headers: { ...CORS, "Content-Type": "text/calendar; charset=utf-8", "Cache-Control": "max-age=3600", "Content-Disposition": 'inline; filename="varv-lopp.ics"' } });
  }
  const t = q.get("t") || "";
  if (!/^[0-9a-f]{32}$/.test(t)) return new Response("Saknas", { status: 404 });
  const { data } = await SB.from("cal_feeds").select("ics").eq("token", t).maybeSingle();
  if (!data || !data.ics) return new Response("Saknas", { status: 404 });
  return new Response(data.ics, {
    headers: { "Content-Type": "text/calendar; charset=utf-8", "Cache-Control": "max-age=1800", "Content-Disposition": 'inline; filename="varv.ics"' },
  });
});
