# VARV. som app

Appen för iPhone och Android byggs med Capacitor av exakt samma filer som webbsidan på varvtraining.com.
Ni fortsätter alltså ändra i `index.html` i roten som vanligt. Appen hämtar ändringarna nästa gång den byggs.

## Så hänger det ihop

- `scripts/kopiera-webb.mjs` kopierar webbsidans filer till `www/` (skapas vid bygget och sparas inte i git).
- `ios/` och `android/` är de riktiga appprojekten.
- `assets/` är källbilderna för ikon och startbild. Ändras de körs `npx capacitor-assets generate` igen.
- I koden avgör `IS_NATIVE` de få saker som skiljer appen från webben: ingen service worker, länkar i mejl går till webbsidan,
  externa länkar öppnas i telefonens webbläsare, och webbnotiser är avstängda i väntan på riktiga notiser.

## Bygga

Byggen görs i molnet med Codemagic, se `codemagic.yaml` i roten:

- **Android – testversion (APK)**: ger en fil som installeras direkt på en Android-telefon.
- **iPhone – TestFlight**: kräver Apple Developer-konto och en App Store Connect API-nyckel i Codemagic.

Lokalt, med Node 22: `npm install` och sedan `npm run sync`. På en Mac öppnar `npm run ios` projektet i Xcode.

## Fast för alltid

App-id `com.varvtraining.app` går inte att byta när appen väl finns i App Store eller Google Play.

## Klockor

Från klockan startar man ett förberett eller färdigt pass, kör det set för set och sparar det i VARV.
Klockan pratar själv med kontot genom funktionerna i `supabase/klocka.sql`. Telefonen behövs bara för att koppla klockan.
Passen på klockan är samma som under Förberedda och Färdiga pass i appen. Appen skickar dem till kontot så fort något ändras.

### Apple Watch

- `ios/App/VarvWatch/` är klockappen, skriven i SwiftUI. Den följer med i samma bygge som iPhone-appen och installeras tillsammans med den.
- `ios/App/App/VarvWatch.swift` är bryggan i iPhone-appen. Den lämnar över klockans nyckel när man är inloggad.
- Klockappen använder inte Hälsa. Passet sparas bara i VARV. Tiden räknas från klockslag, så den stämmer även när skärmen har varit släckt.
- Klockappens Bundle ID är `com.varvtraining.app.watchkitapp` och ska alltid ha samma version som iPhone-appen. Bygget i Codemagic ser till det.

En gång, innan första bygget med klockappen:

1. Gå till developer.apple.com, Certificates, Identifiers & Profiles, Identifiers. Skapa ett App ID med Bundle ID `com.varvtraining.app.watchkitapp`.
2. Under Profiles: skapa en profil av typen App Store Connect för det nya App ID:t, med samma certifikat som iPhone-appen.
3. I Codemagic: Teams, Code signing identities, iOS provisioning profiles, Fetch profiles. Välj den nya profilen och ge den ett namn.
4. Starta bygget iPhone – TestFlight som vanligt.

Inför granskningen i App Store Connect krävs minst en skärmbild från Apple Watch.

### Garmin

`garmin/` är en egen app för Connect IQ, skriven i Monkey C. Se `garmin/README.md` för hur den byggs och publiceras.

### Amazfit

`zepp/` är en egen app för Amazfit-klockor med Zepp OS 3 eller senare, skriven i JavaScript. Se `zepp/README.md`.

### Apple Hälsa

`ios/App/App/VarvHealth.swift` läser träningspass och puls från Hälsa i iPhone-appen. Det är vägen in för klockor som inte kan få en egen VARV.-app, som Amazfit GTR 2, Polar och Suunto. Man slår på det under Profil, Inställningar, Apple Hälsa.

VARV. läser bara, skriver aldrig. Ett pass från Hälsa sparas med id `health-` och den unika nyckeln från Hälsa, så att det inte hämtas två gånger. Ett pass man tar bort döljs i stället, precis som pass från Strava.

En gång, innan första bygget med Hälsa:

1. Gå till developer.apple.com, Certificates, Identifiers & Profiles, Identifiers. Öppna `com.varvtraining.app`, kryssa i HealthKit och tryck Save.
2. Under Profiles: öppna iPhone-appens App Store-profil, tryck Edit och sedan Save, så att profilen får med HealthKit.
3. I Codemagic: ta bort den gamla profilen för `com.varvtraining.app` under Code signing identities och hämta den nya med Fetch profiles.

Apple granskar appar som använder Hälsa extra noga. Integritetspolicyn (`legal/integritet.html`) beskriver vad som läses och att det aldrig används till reklam.
