# VARV.

Träningsapp för Hyrox: stationsguider, plan efter måltid, splittider, racetidtagning med ljud, röst och vibration, logg och racepass för Garmin. Fungerar offline när sidan väl laddats.

VARV. är ett fristående projekt och har ingen koppling till HYROX.

Följ VARV.: [TikTok](https://www.tiktok.com/@varvtraining) · [LinkedIn](https://www.linkedin.com/company/varv)

Intern sida för teamet: adressen delas bara internt (kräver kod, se `supabase/stats.sql`).

## Inloggning med Supabase

Appen kräver konto när Supabase är inkopplat. Pass, rekord och inställningar sparas i kontot och följer med mellan enheter. Vid utloggning rensas de från enheten.

Sätt upp det så här:

1. Skapa ett projekt på supabase.com.
2. Öppna SQL Editor, klistra in innehållet i `supabase/schema.sql` och kör det.
3. Under Authentication → URL Configuration: sätt Site URL till `https://varvtraining.com/` och lägg till samma adress under Redirect URLs (lägg även till `http://localhost:8000/` om du testar lokalt).
4. Kopiera projektets URL och publika nyckel (anon eller publishable) till `supabase-config.js`. Använd aldrig service_role- eller secret-nyckeln.
5. Valfritt, Google: slå på Google under Authentication → Providers med klient-id och hemlighet från Google Cloud Console och sätt `google: true` i `supabase-config.js`.
6. Valfritt, inloggning med kod: lägg till `{{ .Token }}` i mallen Magic Link under Authentication → Emails, så får man en sexsiffrig kod i mejlet. Det behövs på iPhone när appen ligger på hemskärmen, eftersom länkar i mejl öppnas i Safari och inte i appen.

Inloggningssätt: e-post och lösenord, kod eller länk via e-post, glömt lösenord och Google.

## Övningsbiblioteket

`data/exercises.json` byggs med `scripts/build-exercises.py` från [free-exercise-db](https://github.com/yuhonas/free-exercise-db) (public domain) och egna tillägg i skriptet.

## Konto, integritet och säkerhet

- På hemsidan måste man skapa konto efter startanimationen. Man godkänner villkoren, samtycker till att träningsdata sparas och intygar att man är 16 år eller äldre. Samtycket sparas på kontot.
- Integritetspolicy: `legal/integritet.html`. Användarvillkor: `legal/villkor.html`.
- Radera konto i Profil → Konto. Kräver att `supabase/konto.sql` körts i Supabase.
- Rekommenderade inställningar i Supabase under Authentication: Confirm email på, minsta lösenordslängd 10 med bokstäver och siffror, Site URL och Redirect URLs satta till hemsidan.
- Profiler, användarnamn#kod, vänner och profilbilder: kör `supabase/profiler.sql` i Supabase.
- Ekonomi på den interna sidan (fliken Ekonomi): kör `supabase/ekonomi.sql` i Supabase.

Notiser, vänners aktivitet och kalender att prenumerera på

    Kör supabase/notiser.sql i Supabase. Byt först ut HEMLIG_NYCKEL längst ned i avsnittet om inställningar mot en lång slumpad hemlighet.
    Skapa två Edge Functions i Supabase (Edge Functions → Deploy a new function → Via editor): varv-push med koden i supabase/functions/varv-push/index.ts och varv-cal med koden i supabase/functions/varv-cal/index.ts. Slå av "Enforce JWT verification" för båda.
    Lägg in hemligheterna under Edge Functions → Secrets: VAPID_PUBLIC_KEY (samma som pushKey i supabase-config.js), VAPID_PRIVATE_KEY och CRON_SECRET (samma som HEMLIG_NYCKEL). Den privata nyckeln får aldrig ligga i koden.
    På iPhone fungerar notiser bara när VARV. ligger på hemskärmen (iOS 16.4 eller senare).

Tummar upp, loppkalender och felrapporter

    Kör supabase/varv-2.sql i Supabase. Uppdatera sedan koden i funktionen varv-push med supabase/functions/varv-push/index.ts.
    Lopp läggs till och ändras i Table Editor → events. Appen hämtar listan när den startar. Sätt hidden till true för att dölja ett lopp.
    Felrapporter syns på teamets sida under fliken Fel.

Vänförfrågningar och notiscenter

    Kör supabase/notiscenter.sql i Supabase. Kräver profiler.sql, notiser.sql och varv-2.sql.

Pass ni körde tillsammans

    Kör supabase/kollab.sql i Supabase. Kräver schema.sql, profiler.sql, foljare.sql och notiscenter.sql.
    Den som loggar ett pass kan fråga vänner som följer en tillbaka om de tränade ihop, när passet sparas eller i efterhand från passet i loggen.
    Svarar vännen ja i notiscentret läggs en kopia av passet i vännens logg (id logc + inbjudans nummer) och räknas i vännens statistik. Kopian räknas inte som rekord förrän vännen har ändrat passet.
    Innan filen är körd syns inget av detta i appen.

Simulations-race under Tävlingar

    Kör supabase/simrace.sql i Supabase. Kräver profiler.sql och notiser.sql.
    Race letas upp varje vecka av en schemalagd uppgift, som kontrollerar dem och uppdaterar data/sim-races.json. Kontrollera filen med node scripts/check-sim-races.mjs. Ta bort ett race genom att radera det ur filen och lägga dess key i data/sim-races-blockerade.txt.
    Teamets egna race läggs till i Table Editor → sim_races: title, city och day krävs, url ska börja med https:// och leda till arrangörens anmälan. Sätt hidden till true för att dölja ett race.
    Nästa simulering visas på profilens atletkort och sparas i profiles.card, så ingen ny SQL behövs. Egna race visas om "Visa på min profil" är på, och alla kan stängas av under Redigera profil.
    Användare kan lägga in egna race längst ner under Simuleringar. De sparas i användarens inställningar (mySims) och syns bara för användaren. Inbjudningar är länkar (?lopp=) med uppgifterna i själva länken, och mottagaren får en egen kopia.
    Anmälan sker hos arrangören. Knappen i appen är en markering, inte en bokning.

Följare, blockering och anmälningar

    Kör supabase/foljare.sql i Supabase och uppdatera sedan funktionen varv-push med supabase/functions/varv-push/index.ts.
    Anmälningar syns på teamets sida under fliken Fel. Teamet behöver gå igenom dem regelbundet.

Säkerhet och stabil statistik

    Kör supabase/stats.sql igen (koden ändras inte) och därefter supabase/varv-3.sql. Kräver filerna ovan. Går att köra igen.
    varv-3.sql städar profildata från användarna och begränsar felrapporter till 300 i timmen.
    Kör sist supabase/sakerhet.sql. Den låser titel, typ och datum på inlägg, begränsar kommentarer till 30 i timmen och döljer kommentarer mellan personer som har blockerat varandra.

Notis om nya tävlingar

    Kör supabase/nya-tavlingar.sql i Supabase och uppdatera sedan funktionen varv-push med supabase/functions/varv-push/index.ts. Kräver notiser.sql och notiscenter.sql.
    Varje timme jämförs tävlingarna i events och data/events.json och simuleringarna i sim_races och data/sim-races.json med de lopp som redan är kända. Nya lopp ger alla en notis. En ny källa lärs bara in och ger ingen notis.
    data/events.json och data/sim-races.json fylls på av två schemalagda uppgifter i Claude varje måndag. Kontrollera dem med node scripts/check-events.mjs och node scripts/check-sim-races.mjs. Lopp som läggs in för hand i tabellerna gäller före filen.

Öppen tävlingskalender

    varvtraining.com/tavlingar/ och en sida per land byggs av node scripts/build-kalender.mjs från data/events.json och data/sim-races.json, tillsammans med sitemap.xml. De schemalagda uppgifterna kör skriptet varje måndag. Ändra inte de byggda filerna för hand.
    Knappen till appen styrs av APP_URL högst upp i skriptet. Byt den mot butikslänken när appen finns i App Store och Google Play.
    Hyrox nämns bara för att beskriva loppen. Inga logotyper, bilder eller texter från HYROX, och varje sida säger att VARV. är fristående.

Kopplingar att ansöka om

    Strava: skapa en app på strava.com/settings/api. Callback-domän varvtraining.com. Ge client id och secret till den som bygger kopplingen.
    Garmin: ansök till Garmin Connect Developer Program (developer.garmin.com/gc-developer-program). Godkännande tar några veckor.
