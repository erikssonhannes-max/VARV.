# VARV. för Amazfit (Zepp OS)

En app för Amazfit-klockor med Zepp OS 3 eller senare, till exempel GTR 4, GTS 4, T-Rex Ultra och 3, Falcon, Cheetah, Balance och Active.
Den visar Förberedda och Färdiga pass, kör passet set för set och sparar det i VARV.
Appen spelar inte in någon aktivitet i Zepp. Passet sparas bara i VARV.

Äldre Amazfit-klockor, som GTR 2 och GTS 2, kan inte köra egna appar. Deras pass kommer in i VARV. via Apple Hälsa i stället (se app/README.md).

## Så kopplas klockan

1. I VARV.: Profil, Inställningar, Klockor, Koppla en klocka. Koden gäller i 15 minuter.
2. I appen Zepp: öppna VARV. bland klockans appar och tryck Inställningar. Skriv in koden. Under fältet står det när klockan är kopplad.
3. Öppna VARV. på klockan.

## Så hänger det ihop

- `page/`: sidorna på klockan. `index` är listan med pass, `pass` ett pass innan det startar och `live` passläget och sammanfattningen.
- `shared/workout.js`: passets klocka och steg. Samma regler som passläget i appen och Garmin-appen.
- `app-side/index.js`: sidotjänsten, som körs i appen Zepp på telefonen. Den byter koden mot klockans nyckel, hämtar passen och sparar pass med funktionerna i `supabase/klocka.sql`.
- `setting/index.js`: fältet för koden i appen Zepp.

Klockan når nätet genom telefonen, så appen Zepp måste vara igång och telefonen i närheten när passen hämtas och sparas.
Ett pass som inte går att spara direkt ligger kvar på klockan och skickas nästa gång appen öppnas.

## Bygga

Kräver Node och Zeppos verktyg, som fungerar på Windows.

1. `npm install -g @zeppos/zeus-cli`
2. I mappen `app/zepp`: `npm install`
3. `zeus dev` startar appen i simulatorn. Simulatorn hämtas från developer Zepp OS-sidorna.
4. Skapa appen på console.zepp.com. Byt `appId` i `app.json` mot numret du får där.
5. `zeus build` gör en fil som laddas upp på console.zepp.com.

Adressen och den publika nyckeln till Supabase står högst upp i `app-side/index.js` och är samma som i `supabase-config.js`.
