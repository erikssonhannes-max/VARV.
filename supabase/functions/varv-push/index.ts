// VARV. – skickar notiser.
// Anropas av databasen: varje timme ({"kind":"daily"}) och när en vän loggar
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
  const { data } = await SB.from("push_subs").select("*");
  let sent = 0;
  for (const s of (data || []) as Sub[]) {
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

async function runTest(user: string) {
  return await notify([user], { title: "Notiserna fungerar", body: "Så här ser det ut när VARV. påminner dig om dagens pass.", url: "/#hem", tag: "test" }, "test", null, null);
}

Deno.serve(async (req) => {
  if (req.headers.get("x-varv-secret") !== Deno.env.get("CRON_SECRET")) return new Response("Nej", { status: 401 });
  const b = await req.json().catch(() => ({}));
  const n = b.kind === "daily" ? await runDaily() : b.kind === "activity" ? await runActivity(+b.id) : b.kind === "like" ? await runLike(+b.activity, String(b.user)) : b.kind === "test" ? await runTest(String(b.user))
    : b.kind === "request" ? await runRequest(String(b.from), String(b.to)) : b.kind === "accept" ? await runAccept(String(b.from), String(b.to)) : b.kind === "follow" ? await runFollow(String(b.from), String(b.to)) : 0;
  return Response.json({ sent: n });
});
