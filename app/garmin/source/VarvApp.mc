using Toybox.Application as App;
using Toybox.Communications as Comm;
using Toybox.WatchUi as Ui;
using Toybox.System as Sys;
using Toybox.Lang as Lang;

// VARV. för Garmin: välj ett förberett eller färdigt pass, kör det och spara det i kontot.
// Klockan kopplas med en kod från appen, som skrivs in i Garmin Connect under appens inställningar.
// All kontakt med kontot går via funktionerna i supabase/klocka.sql.
class VarvApp extends App.AppBase {

    // Samma publika adress och nyckel som webbsidan använder (supabase-config.js).
    const URL = "https://kwjnezbazyahyzsmpuyg.supabase.co/rest/v1/rpc/";
    const KEY = "sb_publishable_rsSw4ZNaOGdesoK8KkA55Q_1qZCngdD";

    var token = null;     // klockans nyckel till kontot
    var passes = null;    // listan med pass, utan övningar
    var workout = null;   // passet som körs
    var wantedId = null;  // passet som hämtas just nu
    var sending = null;   // passet som sparas just nu
    var busy = false;

    function initialize() {
        AppBase.initialize();
    }

    function onStart(state) {
        token = App.Storage.getValue("token");
        passes = App.Storage.getValue("passes");
    }

    function onStop(state) {
    }

    // Första vyn visar vad som händer medan klockan kopplas eller passen hämtas.
    function getInitialView() {
        var m = plan();
        return [new MessageView(m[0], m[1]), new MessageDelegate(:retry)];
    }

    // Garmin Connect har sparat nya inställningar: prova koden direkt.
    function onSettingsChanged() {
        if (token == null && workout == null) {
            begin();
        }
    }

    // ---------- Anrop mot kontot ----------

    function call(name, params, callback) {
        var options = {
            :method => Comm.HTTP_REQUEST_METHOD_POST,
            :headers => {
                "Content-Type" => Comm.REQUEST_CONTENT_TYPE_JSON,
                "apikey" => KEY,
                "Authorization" => "Bearer " + KEY
            },
            :responseType => Comm.HTTP_RESPONSE_CONTENT_TYPE_JSON
        };
        Comm.makeWebRequest(URL + name, params, options, callback);
    }

    // Kontot känner inte igen nyckeln: klockan har kopplats bort i appen.
    function rejected(code) {
        return code == 401 || code == 403;
    }

    function unlink() {
        token = null;
        passes = null;
        App.Storage.deleteValue("token");
        App.Storage.deleteValue("passes");
    }

    // ---------- Start: koppla, hämta passen, skicka det som väntar ----------

    // Startar nästa steg och svarar med rubriken och texten som ska visas under tiden.
    function plan() {
        if (token == null) {
            var code = App.Properties.getValue("code");
            if (code == null || !(code instanceof Lang.String) || code.length() < 8) {
                return ["Koppla klockan", "Hämta en kod i VARV. under Profil, Inställningar, Klockor. Skriv in den i Garmin Connect under appens inställningar."];
            }
            busy = true;
            call("watch_claim", { "p_code" => code, "p_name" => "Garmin" }, method(:onClaim));
            return ["VARV.", "Kopplar klockan..."];
        }
        busy = true;
        call("watch_sync", { "p_token" => token }, method(:onSync));
        return ["VARV.", "Hämtar dina pass..."];
    }

    function begin() {
        if (busy) {
            return;
        }
        var m = plan();
        show(m[0], m[1]);
    }

    function onClaim(code, data) {
        busy = false;
        if (code == 200 && data != null && data["token"] != null) {
            token = data["token"];
            App.Storage.setValue("token", token);
            App.Properties.setValue("code", "");
            begin();
        } else if (code == 400) {
            App.Properties.setValue("code", "");
            show("Koppla klockan", "Koden stämmer inte eller har gått ut. Hämta en ny i VARV. och skriv in den i Garmin Connect.");
        } else {
            show("Ingen kontakt", "Klockan når inte VARV. Kontrollera att telefonen är i närheten och tryck START.");
        }
    }

    function onSync(code, data) {
        busy = false;
        if (code == 200 && data != null && data["passes"] != null) {
            passes = data["passes"];
            App.Storage.setValue("passes", passes);
            flush();
            showMenu();
        } else if (rejected(code)) {
            unlink();
            begin();
        } else if (passes != null && passes.size() > 0) {
            // Utan kontakt visas passen som hämtades senast.
            showMenu();
        } else {
            show("Ingen kontakt", "Passen gick inte att hämta. Kontrollera att telefonen är i närheten och tryck START.");
        }
    }

    // ---------- Vyer ----------

    function show(title, text) {
        Ui.switchToView(new MessageView(title, text), new MessageDelegate(:retry), Ui.SLIDE_IMMEDIATE);
    }

    function showMenu() {
        if (passes == null || passes.size() == 0) {
            show("Inga pass än", "Öppna VARV. på telefonen en gång, så skickas passen hit. Tryck sedan START.");
            return;
        }
        var menu = new Ui.Menu2({ :title => "VARV." });
        for (var i = 0; i < passes.size(); i += 1) {
            var p = passes[i];
            var sub = p["c"] + (p["c"] == 1 ? " övning" : " övningar");
            if (p["m"] != null) {
                sub = p["m"].toNumber() + " min - " + sub;
            }
            menu.addItem(new Ui.MenuItem(p["n"], sub, p["id"], {}));
        }
        Ui.switchToView(menu, new PassMenuDelegate(), Ui.SLIDE_IMMEDIATE);
    }

    // ---------- Ett pass ----------

    function openPass(id) {
        if (busy) {
            return;
        }
        busy = true;
        wantedId = id;
        Ui.pushView(new MessageView("VARV.", "Hämtar passet..."), new MessageDelegate(:back), Ui.SLIDE_LEFT);
        call("watch_pass", { "p_token" => token, "p_id" => id }, method(:onPass));
    }

    // Den som backar ur medan passet hämtas ska inte få upp det ändå.
    function cancelPass() {
        wantedId = null;
    }

    function onPass(code, data) {
        busy = false;
        if (wantedId == null) {
            return;
        }
        var pass = null;
        if (code == 200 && data != null && data["pass"] != null) {
            pass = data["pass"];
            App.Storage.setValue("p_" + wantedId, pass);
        } else if (rejected(code)) {
            Ui.popView(Ui.SLIDE_IMMEDIATE);
            unlink();
            begin();
            return;
        } else {
            // Utan kontakt används passet som hämtades senast, om det finns.
            pass = App.Storage.getValue("p_" + wantedId);
        }
        if (pass == null || pass["items"] == null || pass["items"].size() == 0) {
            Ui.switchToView(new MessageView("Ingen kontakt", "Passet gick inte att hämta. Tryck BACK och försök igen."), new MessageDelegate(:back), Ui.SLIDE_IMMEDIATE);
            return;
        }
        Ui.switchToView(new PassView(pass), new PassDelegate(pass), Ui.SLIDE_IMMEDIATE);
    }

    function startWorkout(pass) {
        workout = new Workout(pass);
        Ui.switchToView(new LiveView(workout), new LiveDelegate(workout), Ui.SLIDE_IMMEDIATE);
    }

    // Passet är slut eller avslutat i förtid: visa sammanfattningen.
    function showSummary() {
        Ui.switchToView(new SummaryView(workout), new SummaryDelegate(), Ui.SLIDE_IMMEDIATE);
    }

    // Stänger passet och går tillbaka till listan. Vyn för passet ligger överst på listan.
    function closeWorkout() {
        workout = null;
        Ui.popView(Ui.SLIDE_RIGHT);
    }

    // ---------- Spara ----------

    // Lägger passet i kön och skickar det. Kön ligger kvar på klockan tills kontot har svarat.
    function saveWorkout() {
        if (workout == null || !workout.anyDone()) {
            return;
        }
        var queue = App.Storage.getValue("pending");
        if (queue == null) {
            queue = [];
        }
        queue.add({ "id" => workout.id, "pass" => workout.result() });
        App.Storage.setValue("pending", queue);
        workout.saved = true;
        flush();
    }

    function flush() {
        if (sending != null || token == null) {
            return;
        }
        var queue = App.Storage.getValue("pending");
        if (queue == null || queue.size() == 0) {
            return;
        }
        sending = queue[0]["id"];
        call("watch_log", { "p_token" => token, "p_id" => queue[0]["id"], "p_pass" => queue[0]["pass"] }, method(:onLogged));
    }

    function onLogged(code, data) {
        var id = sending;
        sending = null;
        // 200: sparat. 400: kontot tar inte emot passet hur många gånger det än skickas, så det får inte stoppa kön.
        if (code == 200 || code == 400) {
            var queue = App.Storage.getValue("pending");
            var rest = [];
            if (queue != null) {
                for (var i = 0; i < queue.size(); i += 1) {
                    if (!queue[i]["id"].equals(id)) {
                        rest.add(queue[i]);
                    }
                }
            }
            App.Storage.setValue("pending", rest);
            if (workout != null && workout.id.equals(id)) {
                workout.sent = (code == 200);
                workout.failed = (code == 400);
            }
            flush();
        } else if (rejected(code)) {
            unlink();
        }
        Ui.requestUpdate();
    }
}

function getApp() {
    return App.getApp();
}
