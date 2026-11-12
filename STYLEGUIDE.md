# VARV. Stilguide

VARV. är en träningsapp för Hyrox. Den ska se ut och kännas som en app från Apple: lugn, tydlig och snabb att läsa mitt i ett pass, med en enda het färg som visar vart blicken ska.

## De sju reglerna

1. **En het yta per vy.** Gradienten `hot` (rosa till korall) används på ett ställe: primärknappen, nedräkningen eller det viktigaste kortet. Allt annat är vitt, svart och grått.
2. **Grått bär innehållet.** Sidan är `bg`, innehåll ligger på `tile`, fält och plattor inne i en tile på `card`. Inga ramar och inga skuggor på kort.
3. **Stora rubriker, korta ord.** Varje flik börjar med en `eyebrow` i versaler och en `large-title` som slutar med punkt: "Din plan.".
4. **Siffror först.** Tider, tempo och antal står stort och i `tabular-nums`. Text förklarar siffran, inte tvärtom.
5. **Färg betyder något.** Rosa är löpning och varumärket, grönt är stationer och avklarat, turkos är Roxzone och återhämtning. Färg är aldrig ensam bärare av betydelse.
6. **Allt rör sig mjukt, inget blinkar.** Korta, fjädrande animationer när något händer. Inget rör sig utan anledning.
7. **Namnet är alltid VARV.** Versaler och punkt, även mitt i en mening.

## Färger

Hex för ljust och mörkt tema. Använd alltid token, aldrig hex direkt i kod.

| Token | Ljust | Mörkt | Används till |
| --- | --- | --- | --- |
| `bg` | #ffffff | #000000 | Sidans bakgrund |
| `tile` | #f4f4f6 | #141416 | Kort, listor, rutor |
| `card` | #ffffff | #232327 | Fält och plattor inne i en tile |
| `ink` | #111114 | #f5f5f7 | All text och alla siffror |
| `muted` | #6e6e76 | #9a9aa3 | Etiketter, beskrivningar, fotnoter |
| `hair` | #dcdce1 | #2e2e33 | Avdelare i listor, ramar runt fält |
| `accent` | #f0124a | #ff2d55 | Varumärket, löpning, aktiv flik |
| `accent2` | #ff6a3d | #ff7a45 | Slutet på gradienten `hot`, aldrig ensam |
| `link` | #e0123f | #ff4d6d | Textlänkar som "Ändra" och "Rensa" |
| `green` | #1fae4b | #30d158 | Stationer, avklarat, minutringen |
| `cyan` | #0aa7c4 | #32c8e6 | Roxzone, återhämtning, lättare vecka |
| `good` | #1a9a45 | #30d158 | Före plan, alltid med tecken: −0:12 |
| `bad` | #e0123f | #ff4d6d | Efter plan och fel, alltid med tecken: +0:08 |

Dagar och kalendrar följer samma färger: grönt för ett loggat pass, turkos (`cyan`) för vila och ljust turkos (`cyan2`) för aktiv vila. Text i versaler är alltid halvfet, med spärrning 0,04em.

**Hot** = `linear-gradient(135deg, accent, accent2)`. Text på hot är vit, halvfet och minst 16px.

| Gör så | Inte så |
| --- | --- |
| En primärknapp i hot per vy | Två eller fler heta ytor på samma skärm |
| Grått kort på vit sida | Kort med ram eller skugga |
| −0:12 i grönt | Grön text utan tecken eller ord |
| `muted` för hjälptext | Grå text som mindre än 13px |
| Text i `accent` från 15px halvfet | Liten tunn text i rosa på grått |

## Typografi

En familj: systemtypsnittet, som blir SF Pro på Apple-enheter. Rubriker har negativ spärrning och `text-wrap: balance`.

| Stil | Storlek | Vikt | Används till |
| --- | --- | --- | --- |
| `hero` | 104px | 800 | "8 × 1 km." på Hem, bara där |
| `large-title` | 51px | 600 | Flikens titel: "Din plan." |
| `title` | 22px | 600 | Sektionsrubrik: "Träningsschema" |
| `headline` | 21px | 600 | Titel i kort: "Intervaller" |
| `number` | 35px | 700 | Siffror i rutor: "1:30" |
| `body` | 17px | 400 | Brödtext och listrader |
| `callout` | 15px | 400 | Beskrivningar i `muted` |
| `caption` | 13px | 400 | Fotnoter och källor i `muted` |
| `eyebrow` | 13px | 600 | "TRÄNING" ovanför titeln, versaler |
| `tab-label` | 10,5px | 500 | Etiketter i flikraden |

Vid mobilbredd skalas `hero` och `large-title` ned med `clamp()`, aldrig under 34px.

I koden finns skalan som variabler. Använd alltid dessa och skriv aldrig egna storlekar:

| Variabel | Storlek | Används till |
| --- | --- | --- |
| `--t-micro` | 11px | Korta versala etiketter på små ytor, som medaljer och kort |
| `--t-cap` | 13px | Fotnoter, etiketter, `eyebrow` |
| `--t-sub` | 15px | Beskrivningar, länkar, listrader i kort |
| `--t-body` | 17px | Brödtext, knappar, fält |
| `--t-lead` | 19px | Ingress och siffror i små rutor |
| `--t-head` | 22px | Sektionsrubriker och korttitlar |
| `--t-num`, `--t-num-l` | 28px, 35px | Siffror i rutor |
| `--t-num-xl` | 42–54px | Huvudsiffran på ett kort |
| `--t-sheet` | 28–32px | Rubrik i ark och i genomgången |
| `--t-title` | 34–51px | Sidans titel |

Bara klockor och nedräkningar får vara större än skalan.

## Avstånd och former

| Token | Värde | Används till |
| --- | --- | --- |
| `space-3` | 10px | Mellan rutor i ett rutnät |
| `space-5` | 16px | Sidmarginal, minst |
| `space-6` | 18px | Innerpadding i kort |
| `space-8` | 34px | Mellan sektioner |
| `radius-md` | 12px | Fält, ikonplattor |
| `radius-2xl` | 20px | Kort, rutor, listor |
| `radius-sheet` | 22px | Ovankant på ark |
| `radius-pill` | 980px | Knappar, chips, taggar |

Allt är byggt för mobil först: högst 760px brett, minst 44px höga tryckytor, och safe area runt kanterna.

## Så är en skärm uppbyggd

1. **Profilbild** uppe till höger, på alla flikar utom Profil.
2. **Sidhuvud:** `eyebrow`, `large-title` med punkt och en mening i `muted` som säger vad man gör här.
3. **Huvudsaken först:** dagens pass, nedräkningen eller tidtagningen.
4. **Sektioner** med `title` och en länk till höger ("Ändra", "Alla tävlingar").
5. **Fotnot** i `caption` när siffror kommer från en källa.
6. **Flikraden** längst ned: Hem, Stationer, Aktivitet, Tävla, Statistik. Aldrig fler än fem flikar. Planen nås från Hem (Den här veckan och Ditt lopp), profilen från profilbilden.

Formulär öppnas i ett ark som glider upp, inte mitt på sidan. Bekräftelser visas som en toast längst ned.

## Röst och text

Svenska, du-form, korta meningar. Knappar börjar med ett verb. Bekräftelser i dåtid.

| Skriv så | Inte så |
| --- | --- |
| Logga passet | Klicka här för att logga |
| Passet är sparat | Ditt pass har nu sparats! |
| Du hann 2 av 8 pass | Du har missat mycket träning |
| Gör till mitt lopp | Välj detta evenemang |
| 5:38 /km | 5 min 38 sek per kilometer |
| Kunde inte spara. Försök igen. | Ett fel uppstod |

- Stationsnamnen skrivs som HYROX skriver dem: SkiErg, Sled Push, Sled Pull, Burpee Broad Jumps, Rowing, Farmers Carry, Sandbag Lunges, Wall Balls.
- Sektionsrubriker har ingen punkt. Sidrubriker har det.
- Inga emoji och inga utropstecken, utom "Mål!" i tidtagningen.

## Rörelse och känsla

| Vad | Hur | Tid |
| --- | --- | --- |
| Flik öppnas | Kort glider upp 14px och tonar in, i följd | 0,55 s, 50 ms mellan |
| Siffror på Hem | Räknas upp från noll | 0,8 s |
| Knapptryck | Krymper till 97 % och får en lätt vibration | 0,15 s |
| Ark | Glider upp med lätt fjädring | 0,45 s |
| Ringar och staplar | Fylls och växer upp | 1,1 s |
| Milstolpe | Konfetti i varumärkets färger och dubbel vibration | 1,8 s |
| Start | Ikonen poppar, banan ritas, löparen landar | högst 2 s |

Kurvor: lättnad `cubic-bezier(.2,.8,.2,1)`, fjädring `cubic-bezier(.34,1.4,.64,1)`. Konfetti bara vid nytt rekord, uppnått veckomål och målgång. All rörelse stängs av när telefonen har minskade rörelser påslaget.

## Ikoner och bilder

- Systemikoner: linjeikoner på 24px-rutnät, 1,8px linje, rundade ändar, i `currentColor`.
- Stationsikoner: egna linjeteckningar av utrustningen, 64px-rutnät, 2,4px linje, i `ink` på en `card`-platta.
- Inga foton av personer och inga bilder eller logotyper från HYROX.

## Namn och logotyp

- Namnet är **VARV.**, i versaler med punkt. VARV. är fristående och har ingen koppling till HYROX. Nämn Hyrox bara för att beskriva loppet appen tränar för.
- **Appikon** (`varv-icon.svg`): rundad kvadrat i hot med vitt märke. Hemskärm, favikon och små ytor. Minst 24px.
- **Märke** (`varv-mark.svg`): löparbanan som en öppen ring med löparen som en punkt i öppningen. Vitt på färg, hot eller `ink` på `bg`.
- **Ordbild** (`varv-wordmark.svg`, mörk grund: `varv-wordmark-white.svg`): ikonen följd av "VARV.". Minst 120px bred.
- Frizon: minst punktens diameter runt logotypen.

| Gör så | Inte så |
| --- | --- |
| Logotypen i originalfärger | Nya färger i gradienten |
| Vit version på foto eller färg | Skugga, kontur eller glöd på märket |
| Rak och oförändrad | Roterad, sträckt eller beskuren |
| VARV. | Varv, varv eller VARV utan punkt |

## Framsteg och belöningar

Belöningar ska kännas som Apple Fitness, inte som ett spel. Inga ord som XP, level up eller poäng. Färgerna i medaljerna är den enda plats där metalltoner används.

| Del | Vad den visar | Regel |
| --- | --- | --- |
| **Form** | Ett tal och en kurva för de senaste tio veckorna, plus en streckad linje till loppet om du följer planen | Viktat snitt av träningen de senaste sex veckorna. Hårda pass räknas lite mer. En nedgång visas i grått, aldrig i rött. |
| **Varv** | Hur mycket du har tränat | Ett varv per tio minuter, högst tolv per pass. Två extra för ett pass från planen och fem extra för ett klarat veckomål. |
| **Nivåer** | Start, Brons, Silver, Guld, Platina, Elit | 0, 50, 150, 350, 700 och 1 200 varv. Nivån sjunker aldrig. |
| **Utmärkelser** | 38 medaljer i sex familjer: flit och plan, tid, svit, stationer, rekord och lopp, hemliga | Formen visar familjen: cirkel, hexagon, sköld, rundad kvadrat, rosett. Serier byter kant från brons via silver, guld och platina till rosa. Tagen är i färg med glans, inte tagen är grå med en ring som visar hur långt du har kommit. Hemliga visas som ? tills de är tagna. |
| **Topplista** | Varv denna vecka, flikarna Vänner och Alla | Jämför flit, inte fart. Börjar om på måndag. Du syns bara om du har slagit på reglaget. |

Medaljfärger efter typ: hot för antal och plan, turkos för tid, grönt för veckor och stationer, guld för rekord och lopp.

En ny utmärkelse eller nivå visas i ett ark med stor medalj, en glansanimation, konfetti och en dubbel vibration. Visa högst ett sådant ark åt gången.

## Dela i flödet

Aktivitet är en plats för gemenskap, inte ett socialt medium. Det finns ett enda sätt att lägga ut något: att dela ett pass.

- **Ett pass, ett inlägg.** Tid, sträcka, övningar och passets rekord står i samma inlägg. Rekord läggs aldrig ut för sig.
- **Bara summeringsbilder.** Flödet och profilerna visar bara inlägg med passbilden. Databasen nekar allt annat (`supabase/endast-passbilder.sql`).
- **När:** direkt efter passet visas arket "Vill du dela passet?". Väljer man Inte nu går passet att dela senare under Statistik, Pass, i passets ark.
- **Bilden:** 1080 × 1350 (4:5). Bakgrunden är Mörk eller Ljus, med löparbanan uppe till höger, eller en egen bild från kameran eller biblioteket. På en egen bild ligger texten direkt på fotot med en mjuk skugga nedtill, som hos Strava.
- **Innehåll uppifrån:** logotypen, `eyebrow` med typ och datum, passets namn med punkt, tre siffror (Tid, Löpning eller Sträcka, Övningar), rekorden och sedan övningarna rad för rad.
- **Rekord är alltid gröna** och står med förbättringen i procent: "▲ 4,2 % snabbare" och förra tiden bredvid.
- Den egna texten blir bildtext under bilden. Vänner taggas med @.

## Genomgång

Första gången appen öppnas efter starttestet får användaren en genomgång i tio steg. Varje steg tonar ner skärmen och lyfter fram en del med en ljus ring, med ett kort som har stegnummer, rubrik, en eller två meningar och knapparna Tillbaka och Nästa. Hoppa över finns alltid. Genomgången kan visas igen under Profil, Hjälp.

## För dig som kodar

All kod ligger i `index.html`. Färgerna är CSS-variabler på `:root` med egna värden för mörkt läge. Använd alltid variablerna, aldrig hex direkt.

| Stilguiden | I koden |
| --- | --- |
| `bg`, `tile`, `card`, `ink`, `muted`, `hair` | `var(--bg)`, `var(--tile)`, `var(--card)`, `var(--ink)`, `var(--muted)`, `var(--hair)` |
| `accent`, `accent2`, `link` | `var(--accent)`, `var(--accent2)`, `var(--link)` |
| `green`, `cyan`, `good`, `bad` | `var(--green)`, `var(--cyan)`, `var(--good)`, `var(--bad)` |
| `hot` | `var(--hot)` |
| `radius-2xl` | `var(--r)` (20px) |
| Lättnad och fjädring | `var(--ease)`, `var(--spring)` |

| Komponent | Klass i `index.html` |
| --- | --- |
| Primärknapp, sekundärknapp | `.pill`, `.pill.ghost` |
| Kort, ruta, het ruta | `.card`, `.tile`, `.tile.hot` |
| Grupperad lista med rader | `.group` med `.row` |
| Segmentkontroll | `.seg` med `button[aria-pressed]` |
| Chip, pulszon, fas | `.chip`, `.zone`, `.phase` |
| Banner | `.banner` med `.bicon` |
| Ark | `openSheet(html, mount)` i JavaScript |
| Reglage | `.switchrow` med `.sw` |
| Tävlingskort | `.evhero` och `evRow(e)` |
| Profilbild | `.avatar-btn`, `.pf-av` |
| Bekräftelse | `toast("Passet är sparat")` |
| Vibration | `HAPTIC("light" \| "medium" \| "success")` |

Logotyperna finns i mappen `brand/`. 
