// VARV. – skickar notiser.
// Anropas av databasen: varje timme ({"kind":"daily"} och {"kind":"newraces"}) och när en vän loggar
// eller tävlar ({"kind":"activity","id":…}). Se supabase/notiser.sql.
//
// Hemligheter som behövs (Edge Functions → Secrets):
//   VAPID_PUBLIC_KEY, VAPID_PRIVATE_KEY, CRON_SECRET
// SUPABASE_URL och SUPABASE_SERVICE_ROLE_KEY finns redan i alla funktioner.

import webpush from "npm:web-push@3.6.7";
import { createClient } from "npm:@supabase/supabase-js@2";

const SB = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!);
webpush.setVapidDetails("mailto:hej@varvtraining.com", Deno.env.get("VAPID_PUBLIC_KEY")!, Deno.env.get("VAPID_PRIVATE_KEY")!);

type Sub = { endpoint: string; user_id: string; sub: unknown; tz: string; hour: number; prefs: Record<string, boolean>; schedule: any; last_daily: string | null };
type Msg = { title: string; body: string; url?: string; tag?: string };

async function send(s: Sub, m: Msg) {
  try {
    await webpush.sendNotification(s.sub as webpush.PushSubscription, JSON.stringify({ url: "/", ...m }), { TTL: 6 * 3600 });
  } catch (e) {
    const code = (e as { statusCode?: number }).statusCode;
    if (code === 404 || code === 410) await SB.from("push_subs").delete().eq("endpoint", s.endpoint);
  }
}

// Sparar notisen i notiscentret för varje mottagare och skickar den till deras telefoner.
async function notify(users: string[], m: Msg, kind: string, actor: string | null, pref: string | null) {
  users = [...new Set(users)].filter(Boolean);
  if (!users.length) return 0;
  await SB.from("notifications").insert(users.map((u) => ({ user_id: u, kind, title: m.title, body: m.body || null, url: m.url || null, actor })));
  const { data: subs } = await SB.from("push_subs").select("*").in("user_id", users);
  let n = 0;
  for (const s of (subs || []) as Sub[]) if (!pref || s.prefs?.[pref] !== false) { await send(s, m); n++; }
  return n;
}
const nameOf = async (id: string) => (await SB.from("profiles").select("username").eq("user_id", id).maybeSingle()).data?.username || "Någon";

function local(tz: string) {
  const p = Object.fromEntries(new Intl.DateTimeFormat("en-CA", { timeZone: tz, year: "numeric", month: "2-digit", day: "2-digit", hour: "2-digit", hourCycle: "h23", weekday: "short" })
    .formatToParts(new Date()).map((x) => [x.type, x.value]));
  return { date: `${p.year}-${p.month}-${p.day}`, hour: +p.hour, wd: p.weekday as string };
}
const days = (a: string, b: string) => Math.round((Date.parse(a + "T12:00:00Z") - Date.parse(b + "T12:00:00Z")) / 864e5);

const TIPS: [number, string][] = [
  [84, "Se till att bygga grunden nu: jämna löppass och styrka två gånger i veckan."],
  [56, "Se till att träna alla åtta stationer minst en gång varannan vecka."],
  [42, "Se till att köra stationerna i tävlingsvikt och springa direkt efter, så vänjer sig benen."],
  [28, "Se till att boka in en längre racesimulering de närmaste veckorna."],
  [21, "Se till att köra din sista långa simulering nu, sedan börjar nedtrappningen."],
  [14, "Se till att hålla tempot men sänka mängden lite, och sov ordentligt."],
  [7, "Se till att trappa ned: korta, snabba pass och mycket sömn. Testa tävlingsfrukosten."],
  [3, "Se till att kolla starttiden och packa skor med bra grepp."],
  [2, "Se till att ta det lugnt och gå igenom ordningen på stationerna."],
  [1, "Se till att vila, dricka ordentligt och lägga dig i tid."],
];

function daily(s: Sub, now: { date: string; wd: string }): Msg | null {
  const sc = s.schedule || {}, pr = s.prefs || {};
  if (pr.race !== false && sc.race && sc.race.date) {
    const d = days(sc.race.date, now.date), name = sc.race.name || "loppet";
    if (d === 0) return { title: "Tävlingsdag.", body: `Lycka till i ${name}. Gå inte ut för hårt på första kilometern.`, url: "/#race", tag: "race" };
    const tip = TIPS.find(([n]) => n === d);
    if (tip) return { title: `${d} ${d === 1 ? "dag" : "dagar"} till ${name}`, body: tip[1], url: "/#plan", tag: "race" };
  }
  if (pr.plan === false) return null;
  const ses = (sc.sessions || []).find((x: { d: string }) => x.d === now.date);
  if (ses) return { title: `Idag: ${ses.t}`, body: `${ses.m} min enligt din plan. Taggad?`, url: "/#plan", tag: "plan" };
  if (!sc.plan && (now.wd === "Mon" || now.wd === "Thu"))
    return { title: "Gör din plan", body: "Välj ditt lopp och din måltid, så lägger VARV. upp träningen vecka för vecka.", url: "/#plan", tag: "plan" };
  if (sc.last) {
    const gap = days(now.date, sc.last);
    if (gap === 5 || gap === 10) return { title: "Dags för ett pass?", body: "Ett kort pass räknas också. 30 minuter lugn löpning håller igång formen.", url: "/#logg", tag: "plan" };
  }
  return null;
}

async function runDaily() {
  // Hämtas sida för sida, annars missar databasens radgräns de som kommer efter de första tusen.
  const data: Sub[] = [];
  for (let from = 0; ; from += 1000) {
    const { data: page, error } = await SB.from("push_subs").select("*").order("endpoint").range(from, from + 999);
    if (error || !page?.length) break;
    data.push(...(page as Sub[]));
    if (page.length < 1000) break;
  }
  let sent = 0;
  for (const s of data) {
    let now;
    try { now = local(s.tz || "Europe/Stockholm"); } catch { now = local("Europe/Stockholm"); }
    if (now.hour !== s.hour || s.last_daily === now.date) continue;
    await SB.from("push_subs").update({ last_daily: now.date }).eq("endpoint", s.endpoint);
    const m = daily(s, now);
    if (m) {
      await SB.from("notifications").insert({ user_id: s.user_id, kind: m.tag === "race" ? "race" : "plan", title: m.title, body: m.body, url: m.url || null });
      await send(s, m); sent++;
    }
  }
  return sent;
}

async function runActivity(id: number) {
  const { data: a } = await SB.from("activity").select("*").eq("id", id).maybeSingle();
  if (!a) return 0;
  if (a.kind === "pass") {
    const { count } = await SB.from("activity").select("id", { count: "exact", head: true })
      .eq("user_id", a.user_id).eq("kind", "pass").gte("created_at", new Date(Date.now() - 3 * 3600e3).toISOString()).neq("id", a.id);
    if (count) return 0;
  }
  const { data: p } = await SB.from("profiles").select("username").eq("user_id", a.user_id).maybeSingle();
  const name = p?.username || "En vän";
  const { data: fr } = await SB.from("friends").select("friend_id").eq("user_id", a.user_id);
  const ids = (fr || []).map((f) => f.friend_id);
  if (!ids.length) return 0;
  const m: Msg = a.kind === "lopp"
    ? { title: `${name} har precis tävlat`, body: [a.title, a.detail].filter(Boolean).join(" · "), url: "/#vanner", tag: "fr-" + a.user_id }
    : a.kind === "rekord"
    ? { title: `${name} satte nytt rekord`, body: [a.title, a.detail].filter(Boolean).join(" · "), url: "/#vanner", tag: "fr-" + a.user_id }
    : { title: `${name} har tränat`, body: [a.title, a.detail].filter(Boolean).join(" · "), url: "/#vanner", tag: "fr-" + a.user_id };
  return await notify(ids, m, "activity", a.user_id, "friends");
}

async function runLike(activityId: number, liker: string) {
  const { data: a } = await SB.from("activity").select("*").eq("id", activityId).maybeSingle();
  if (!a || a.user_id === liker) return 0;
  const { data: p } = await SB.from("profiles").select("username").eq("user_id", liker).maybeSingle();
  const m: Msg = { title: `${p?.username || "En vän"} gav dig tummen upp`, body: [a.title, a.detail].filter(Boolean).join(" · "), url: "/#vanner", tag: "like-" + a.id };
  return await notify([a.user_id], m, "like", liker, "friends");
}

async function runRequest(from: string, to: string) {
  return await notify([to], { title: `${await nameOf(from)} vill följa dig`, body: "Godkänn eller avböj under ringklockan.", url: "/#notiser", tag: "req-" + from }, "request", from, null);
}
async function runAccept(from: string, to: string) {
  return await notify([to], { title: `${await nameOf(from)} godkände din förfrågan`, body: "Nu ser du personens pass, lopp och veckans varv.", url: "/#vanner", tag: "acc-" + from }, "accept", from, null);
}
async function runFollow(from: string, to: string) {
  return await notify([to], { title: `${await nameOf(from)} började följa dig`, body: "Tryck för att se profilen.", url: "/#notiser", tag: "fol-" + from }, "follow", from, "friends");
}

// ---------- Nya tävlingar och simuleringar (se supabase/nya-tavlingar.sql) ----------
const MON = ["jan", "feb", "mars", "apr", "maj", "juni", "juli", "aug", "sep", "okt", "nov", "dec"];
function when(s: string, e?: string) {
  const a = new Date(s + "T12:00:00Z"), b = new Date((e || s) + "T12:00:00Z");
  if (!e || s === e) return `${a.getUTCDate()} ${MON[a.getUTCMonth()]}`;
  if (a.getUTCMonth() === b.getUTCMonth()) return `${a.getUTCDate()}–${b.getUTCDate()} ${MON[b.getUTCMonth()]}`;
  return `${a.getUTCDate()} ${MON[a.getUTCMonth()]}–${b.getUTCDate()} ${MON[b.getUTCMonth()]}`;
}
const andList = (a: string[]) => a.length < 2 ? a.join("") : a.slice(0, -1).join(", ") + " och " + a[a.length - 1];
type Race = { key: string; kind: "tavling" | "sim"; src: string; name: string; day: string; label: string };
const slug = (s: string) => String(s).normalize("NFD").replace(/[\u0300-\u036f]/g, "").toLowerCase().replace(/[^a-z0-9]+/g, "-").replace(/^-|-$/g, "");
const site = (path: string) => fetch("https://varvtraining.com/" + path, { cache: "no-store" }).then((r) => r.ok ? r.json() : null).catch(() => null);

// Källor: tabellen events och data/events.json (tävlingar), tabellen sim_races och data/sim-races.json (simuleringar).
// Samma tävling på båda ställena får samma nyckel och ger bara en notis.
async function upcomingRaces(): Promise<Race[] | null> {
  const today = new Date().toISOString().slice(0, 10), out: Race[] = [];
  const [ev, sim, evFile, simFile] = await Promise.all([
    SB.from("events").select("city,country,starts,ends").eq("hidden", false).gte("ends", today),
    SB.from("sim_races").select("id,title,city,day").eq("hidden", false).gte("day", today),
    site("data/events.json"),
    site("data/sim-races.json"),
  ]);
  // Saknas någon källa just nu hoppar vi över körningen, annars kan lopp se nya ut nästa gång.
  if (ev.error || sim.error || !evFile || !Array.isArray(evFile.events) || !simFile || !Array.isArray(simFile.races)) return null;
  const tavling = (e: { city: string; country?: string; starts: string; ends: string }, src: string) =>
    out.push({ key: `ev-${e.starts}-${slug(e.city)}`, kind: "tavling", src, name: e.city, day: e.starts, label: `${e.city}${e.country ? ", " + e.country : ""} · ${when(e.starts, e.ends)}` });
  for (const e of ev.data || []) tavling(e, "events");
  for (const e of evFile.events) if (e && e.city && e.starts && e.ends >= today) tavling(e, "events-file");
  for (const r of sim.data || [])
    out.push({ key: `sim-${r.day}-db-${r.id}`, kind: "sim", src: "sim-db", name: r.city, day: r.day, label: `${r.title} · ${r.city}, ${when(r.day)}` });
  for (const r of simFile.races)
    if (r && r.key && r.day >= today) out.push({ key: `sim-${r.key}`, kind: "sim", src: "sim-file", name: r.city, day: r.day, label: `${r.title} · ${r.city}, ${when(r.day)}` });
  return out;
}

function raceMsg(list: Race[], kind: "tavling" | "sim"): Msg {
  const one = list.length === 1, sim = kind === "sim";
  const title = one ? (sim ? "Ny simulering finns nu i appen" : "Ny tävling finns nu i appen")
    : `${list.length} nya ${sim ? "simuleringar" : "tävlingar"} finns nu i appen`;
  const names = [...new Set(list.map((r) => r.name))];
  const body = one ? list[0].label : andList(names.length > 4 ? [...names.slice(0, 3), `${names.length - 3} till`] : names) + ".";
  return { title, body: body.slice(0, 240), url: sim ? "/#race-sim" : "/#race-kal", tag: "new-" + kind };
}

async function runNewRaces() {
  const all = await upcomingRaces();
  if (!all) return 0;
  const { data: fresh, error } = await SB.rpc("varv_new_races", { p_items: all });
  if (error || !Array.isArray(fresh) || !fresh.length) return 0;
  const msgs = (["tavling", "sim"] as const)
    .map((k) => (fresh as Race[]).filter((r) => r.kind === k).sort((a, b) => a.day.localeCompare(b.day)))
    .filter((l) => l.length).map((l) => raceMsg(l, l[0].kind));

  // Notiscentret: alla som har ett konto.
  for (let page = 1; ; page++) {
    const { data, error } = await SB.auth.admin.listUsers({ page, perPage: 1000 });
    if (error || !data?.users?.length) break;
    const rows = data.users.flatMap((u) => msgs.map((m) => ({ user_id: u.id, kind: "newrace", title: m.title, body: m.body, url: m.url })));
    for (let i = 0; i < rows.length; i += 500) await SB.from("notifications").insert(rows.slice(i, i + 500));
    if (data.users.length < 1000) break;
  }
  // Push: alla med notiser påslagna som inte har stängt av Nya tävlingar.
  let n = 0;
  for (let from = 0; ; from += 1000) {
    const { data: page, error } = await SB.from("push_subs").select("*").order("endpoint").range(from, from + 999);
    if (error || !page?.length) break;
    for (const s of page as Sub[]) if (s.prefs?.newraces !== false) for (const m of msgs) { await send(s, m); n++; }
    if (page.length < 1000) break;
  }
  return n;
}

async function runTest(user: string) {
  return await notify([user], { title: "Notiserna fungerar", body: "Så här ser det ut när VARV. påminner dig om dagens pass.", url: "/#hem", tag: "test" }, "test", null, null);
}

Deno.serve(async (req) => {
  if (req.headers.get("x-varv-secret") !== Deno.env.get("CRON_SECRET")) return new Response("Nej", { status: 401 });
  const b = await req.json().catch(() => ({}));
  const n = b.kind === "daily" ? await runDaily() : b.kind === "newraces" ? await runNewRaces() : b.kind === "activity" ? await runActivity(+b.id) : b.kind === "like" ? await runLike(+b.activity, String(b.user)) : b.kind === "test" ? await runTest(String(b.user))
    : b.kind === "request" ? await runRequest(String(b.from), String(b.to)) : b.kind === "accept" ? await runAccept(String(b.from), String(b.to)) : b.kind === "follow" ? await runFollow(String(b.from), String(b.to)) : 0;
  return Response.json({ sent: n });
});
