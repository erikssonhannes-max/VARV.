using Toybox.System as Sys;
using Toybox.Time as Time;
using Toybox.Time.Gregorian as Greg;
using Toybox.Math as Math;
using Toybox.Attention as Attention;

// Ett pass som körs på klockan. Följer samma regler som passläget i appen:
// en övning med flera set går set för set, tiden sparas på övningar där tiden betyder något,
// och en skippad övning sparas inte.
class Workout {

    var pass;            // passet från kontot
    var items;           // övningarna
    var done;            // vilka övningar som blev klara
    var secs;            // tiden per övning, i sekunder
    var cur = 0;         // övningen som pågår
    var setsDone = 0;    // klara set i den övningen
    var startMs;         // när passet började
    var pausedMs = 0;    // sammanlagd paus
    var pausedAt = null; // när pausen började, om passet är pausat
    var exAt = 0;        // passets tid när övningen började
    var finished = false;
    var id;              // passets id i loggen. Samma varje gång passet skickas.
    var date;            // dagen passet började
    var saved = false;   // ligger i kön
    var sent = false;    // kontot har tagit emot det
    var failed = false;  // kontot tog inte emot det

    function initialize(p) {
        pass = p;
        items = p["items"];
        var n = items.size();
        done = new [n];
        secs = new [n];
        for (var i = 0; i < n; i += 1) {
            done[i] = false;
            secs[i] = null;
        }
        startMs = Sys.getTimer();
        var now = Time.now();
        var d = Greg.info(now, Time.FORMAT_SHORT);
        date = d.year.format("%04d") + "-" + d.month.format("%02d") + "-" + d.day.format("%02d");
        id = "w" + now.value().format("%x") + (Math.rand() % 65536).format("%04x");
        buzz(300);
    }

    // ---------- Tid ----------

    function paused() {
        return pausedAt != null;
    }

    // Passets tid i sekunder, utan pauser.
    function elapsed() {
        var now = pausedAt != null ? pausedAt : Sys.getTimer();
        var s = (now - startMs - pausedMs) / 1000;
        return s < 0 ? 0 : s;
    }

    // Tiden i den pågående övningen.
    function exerciseElapsed() {
        var s = elapsed() - exAt;
        return s < 0 ? 0 : s;
    }

    // ---------- Läge ----------

    function current() {
        return items[cur];
    }

    function setCount() {
        var sets = items[cur]["sets"];
        return sets == null ? 0 : sets.size();
    }

    function moreSets() {
        var n = setCount();
        return n > 1 && setsDone < n - 1;
    }

    function isLast() {
        return cur >= items.size() - 1;
    }

    function anyDone() {
        for (var i = 0; i < done.size(); i += 1) {
            if (done[i]) {
                return true;
            }
        }
        return false;
    }

    function doneCount() {
        var n = 0;
        for (var i = 0; i < done.size(); i += 1) {
            if (done[i]) {
                n += 1;
            }
        }
        return n;
    }

    // Övningar där tiden är en del av resultatet: sträckor, kalorier, tidsövningar och stationer.
    function timed(it) {
        var k = it["k"];
        if (k == null) {
            return false;
        }
        return k.equals("d") || k.equals("c") || k.equals("t") || (k.equals("r") && it["st"] == 1);
    }

    // ---------- Steg ----------

    function pauseOrResume() {
        if (pausedAt != null) {
            pausedMs += Sys.getTimer() - pausedAt;
            pausedAt = null;
        } else {
            pausedAt = Sys.getTimer();
        }
        buzz(100);
    }

    // Nästa set, eller nästa övning när sista setet är klart.
    function advance() {
        if (finished || pausedAt != null) {
            return;
        }
        if (moreSets()) {
            setsDone += 1;
            buzz(100);
            return;
        }
        var it = items[cur];
        var sec = exerciseElapsed();
        if (sec < 1) {
            sec = 1;
        }
        done[cur] = true;
        if (timed(it)) {
            secs[cur] = sec;
            // En ensam sträcka eller station får sin tid direkt i setet, som i appen.
            if (setCount() == 1) {
                it["sets"][0]["t"] = sec;
            }
        }
        step();
    }

    // Hoppar över övningen. Den sparas inte med passet.
    function skip() {
        if (finished) {
            return;
        }
        step();
    }

    function step() {
        if (isLast()) {
            finish();
            return;
        }
        cur += 1;
        setsDone = 0;
        exAt = elapsed();
        buzz(300);
    }

    // Avslutar passet där det är. Det som är klart går att spara.
    function finish() {
        if (pausedAt == null) {
            pausedAt = Sys.getTimer();
        }
        finished = true;
        buzz(600);
    }

    function buzz(ms) {
        if (Attention has :vibrate) {
            Attention.vibrate([new Attention.VibeProfile(60, ms)]);
        }
    }

    // ---------- Resultat ----------

    // Passet i den form som kontot tar emot. Bara övningar som blev klara följer med.
    function result() {
        var out = [];
        for (var i = 0; i < items.size(); i += 1) {
            if (done[i]) {
                var it = items[i];
                var o = {
                    "ex" => it["ex"],
                    "n" => it["n"],
                    "k" => it["k"],
                    "w" => it["w"],
                    "st" => it["st"],
                    "sets" => it["sets"]
                };
                if (secs[i] != null) {
                    o["sec"] = secs[i];
                }
                out.add(o);
            }
        }
        var r = {
            "date" => date,
            "total" => elapsed(),
            "name" => pass["n"],
            "items" => out
        };
        if (pass["t"] != null) {
            r["type"] = pass["t"];
        }
        return r;
    }
}

// 754 blir "12:34" och 3723 blir "1:02:03"
function fmtTime(sec) {
    if (sec < 0) {
        sec = 0;
    }
    var h = sec / 3600;
    var m = (sec % 3600) / 60;
    var s = sec % 60;
    if (h > 0) {
        return h + ":" + m.format("%02d") + ":" + s.format("%02d");
    }
    return m + ":" + s.format("%02d");
}
