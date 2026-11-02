# VARV.

Träningsapp för Hyrox: stationsguider, plan efter måltid, splittider, racetidtagning med ljud, röst och vibration, logg och racepass för Garmin. Fungerar offline när sidan väl laddats.

VARV. är ett fristående projekt och har ingen koppling till HYROX.

Följ VARV.: [TikTok](https://www.tiktok.com/@varvtraining) · [LinkedIn](https://www.linkedin.com/company/varv)

Intern sida för teamet: adressen delas bara internt (kräver kod, se `supabase/stats.sql`).

## Inloggning med Supabase

Appen fungerar utan konto. När Supabase är inkopplat kan man skapa konto och logga in, och då sparas pass, rekord och inställningar i kontot och följer med mellan enheter. Det man loggat på enheten innan flyttas till kontot vid första inloggningen.

Sätt upp det så här:

1. Skapa ett projekt på supabase.com.
2. Öppna SQL Editor, klistra in innehållet i `supabase/schema.sql` och kör det.
3. Under Authentication → URL Configuration: sätt Site URL till `https://varvtraining.com/` och lägg till samma adress under Redirect URLs (lägg även till `http://localhost:8000/` om du testar lokalt).
4. Kopiera projektets URL och publika nyckel (anon eller publishable) till `supabase-config.js`. Använd aldrig service_role- eller secret-nyckeln.
5. Valfritt, Google: slå på Google under Authentication → Providers med klient-id och hemlighet från Google Cloud Console och sätt `google: true` i `supabase-config.js`.
6. Valfritt, inloggning med kod: lägg till `{{ .Token }}` i mallen Magic Link under Authentication → Emails, så får man en sexsiffrig kod i mejlet. Det behövs på iPhone när appen ligger på hemskärmen, eftersom länkar i mejl öppnas i Safari och inte i appen.

Inloggningssätt: e-post och lösenord, kod eller länk via e-post, glömt lösenord och Google.

## Konto, integritet och säkerhet

- På hemsidan måste man skapa konto efter startanimationen. Man godkänner villkoren, samtycker till att träningsdata sparas och intygar att man är 16 år eller äldre. Samtycket sparas på kontot.
- Integritetspolicy: `legal/integritet.html`. Användarvillkor: `legal/villkor.html`.
- Radera konto i Profil → Konto. Kräver att `supabase/konto.sql` körts i Supabase.
- Rekommenderade inställningar i Supabase under Authentication: Confirm email på, minsta lösenordslängd 8, Site URL och Redirect URLs satta till hemsidan.
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

Simulations-race under Tävlingar

    Kör supabase/simrace.sql i Supabase. Kräver profiler.sql och notiser.sql.
    Race läggs till och ändras i Table Editor → sim_races: title, city och day krävs, url ska börja med https:// och leda till arrangörens anmälan. Sätt hidden till true för att dölja ett race.
    Anmälan sker hos arrangören. Knappen i appen är en markering, inte en bokning.

Säkerhet och stabil statistik

    Kör supabase/stats.sql igen (koden ändras inte) och därefter supabase/varv-3.sql. Kräver filerna ovan. Går att köra igen.
    varv-3.sql städar profildata från användarna och begränsar felrapporter till 300 i timmen.

Kopplingar att ansöka om

    Strava: skapa en app på strava.com/settings/api. Callback-domän varvtraining.com. Ge client id och secret till den som bygger kopplingen.
    Garmin: ansök till Garmin Connect Developer Program (developer.garmin.com/gc-developer-program). Godkännande tar några veckor.
