# VARV. för Garmin

En app för Connect IQ. Den visar Förberedda och Färdiga pass, kör passet set för set och sparar det i VARV.
Appen spelar inte in någon aktivitet i Garmin Connect. Passet sparas bara i VARV.

## Så kopplas klockan

1. I VARV.: Profil, Inställningar, Klockor, Koppla en Garmin. Koden gäller i 15 minuter.
2. I Garmin Connect på telefonen: välj klockan, Appar, VARV., Inställningar. Skriv in koden.
3. Öppna VARV. på klockan. Klockan byter koden mot en egen nyckel och hämtar passen.

Klockan når nätet genom telefonen, så Garmin Connect måste vara igång och telefonen i närheten när passen hämtas och sparas.
Ett pass som inte går att spara direkt ligger kvar på klockan och skickas nästa gång appen öppnas.

## Knappar

- START: nästa set, nästa övning eller klar.
- BACK: pausa, skippa övningen, avsluta och spara eller släng passet.

## Bygga

Kräver Connect IQ SDK och Visual Studio Code med tillägget Monkey C från Garmin. Det fungerar på Windows.

1. Installera SDK Manager från developer.garmin.com/connect-iq/sdk och hämta senaste SDK och de klockor som står i `manifest.xml`.
2. Öppna mappen `app/garmin` i VS Code. Kör Monkey C: Verify Installation och skapa en utvecklarnyckel när tillägget frågar.
3. Kör Run Without Debugging för att prova i simulatorn. Välj en klocka i listan.
4. Kör Monkey C: Export Project för att få en `.iq`-fil. Ladda upp den på apps.garmin.com/developer.

Listan med klockor i `manifest.xml` ändras med Monkey C: Edit Products. En klocka som inte finns i din SDK ger ett fel vid export. Ta då bort den raden.

## Filer

- `source/VarvApp.mc`: koppling, hämtning av pass och kön med pass som ska sparas.
- `source/Workout.mc`: passets klocka och steg. Samma regler som passläget i appen.
- `source/Views.mc`: vyerna.
- `resources/settings/`: fältet för koden i Garmin Connect.

Adressen och den publika nyckeln till Supabase står högst upp i `source/VarvApp.mc` och är samma som i `supabase-config.js`.
