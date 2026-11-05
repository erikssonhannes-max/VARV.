# VARV.

Varje release får ett nytt versionsnummer. Numret ska alltid vara detsamma i `sw.js`, på sidan (längst ned i Profil och Inställningar) och i felrapporterna.

Ändra det aldrig för hand. Kör `python3 scripts/version.py` före varje push, så höjs sista siffran på alla ställen. Ett annat nummer sätts med `python3 scripts/version.py 1.2.0`, och `python3 scripts/version.py --check` kontrollerar att allt stämmer.

Numret i iPhone- och Android-appen (`app/`) styrs separat av butiksbyggena.
