// VARV. – träningsplanen som kalender att prenumerera på.
// Länken innehåller en hemlig nyckel per användare: …/functions/v1/varv-cal?t=NYCKEL
// Slå av "Enforce JWT verification" för funktionen, annars kan Kalender inte hämta den.
import { createClient } from "npm:@supabase/supabase-js@2";

const SB = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!);

const CORS = { "Access-Control-Allow-Origin": "*" };
const DAY = /^\d{4}-\d{2}-\d{2}$/;
const txt = (v: string) => v.replace(/[\r\n]+/g, " ").slice(0, 80).replace(/([\\;,])/g, "\\$1");

// Ett enskilt lopp: …/functions/v1/varv-cal?ev=1&c=Stad&v=Plats&s=2026-12-10&e=2026-12-13
// iPhone visar då Lägg till i Kalender direkt. Inget sparas och ingen inloggning behövs.
function raceIcs(q: URLSearchParams): string | null {
  const c = q.get("c") || "", s = q.get("s") || "", e = q.get("e") || s;
  if (!c || !DAY.test(s) || !DAY.test(e) || e < s) return null;
  const end = new Date(e + "T12:00:00Z");
  if (isNaN(end.getTime()) || isNaN(new Date(s + "T12:00:00Z").getTime())) return null;
  end.setUTCDate(end.getUTCDate() + 1);
  const d = (x: string) => x.replace(/-/g, "");
  const v = q.get("v") || "";
  return ["BEGIN:VCALENDAR", "VERSION:2.0", "PRODID:-//VARV//SV", "METHOD:PUBLISH", "BEGIN:VEVENT",
    `UID:ev-${c.replace(/\W/g, "")}-${s}@varv`, `DTSTAMP:${new Date().toISOString().replace(/[-:]/g, "").slice(0, 15)}Z`,
    `DTSTART;VALUE=DATE:${d(s)}`, `DTEND;VALUE=DATE:${d(end.toISOString().slice(0, 10))}`,
    `SUMMARY:HYROX ${txt(c)}`, `LOCATION:${txt(v ? v + ", " + c : c)}`, "END:VEVENT", "END:VCALENDAR", ""].join("\r\n");
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
