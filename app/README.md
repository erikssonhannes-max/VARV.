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
