using Toybox.WatchUi as Ui;
using Toybox.Graphics as Gfx;
using Toybox.Timer as Timer;

// VARV.:s rosa och gröna, samma som i appen.
const ACCENT = 0xFF2D55;
const GREEN = 0x30D158;

// Ritar en text som bryts över flera rader och krymper tills den får plats.
function drawWrapped(dc, text, color, y, height, fonts) {
    var w = dc.getWidth();
    var area = new Ui.TextArea({
        :text => text,
        :color => color,
        :font => fonts,
        :locX => (w * 0.12).toNumber(),
        :locY => y,
        :width => (w * 0.76).toNumber(),
        :height => height,
        :justification => Gfx.TEXT_JUSTIFY_CENTER
    });
    area.draw(dc);
}

// ---------- Meddelande: koppla klockan, hämtar, ingen kontakt ----------

class MessageView extends Ui.View {
    var title;
    var text;

    function initialize(t, x) {
        View.initialize();
        title = t;
        text = x;
    }

    function onUpdate(dc) {
        var h = dc.getHeight();
        dc.setColor(Gfx.COLOR_WHITE, Gfx.COLOR_BLACK);
        dc.clear();
        dc.setColor(ACCENT, Gfx.COLOR_TRANSPARENT);
        dc.drawText(dc.getWidth() / 2, (h * 0.14).toNumber(), Gfx.FONT_SMALL, title, Gfx.TEXT_JUSTIFY_CENTER);
        drawWrapped(dc, text, Gfx.COLOR_WHITE, (h * 0.30).toNumber(), (h * 0.56).toNumber(), [Gfx.FONT_TINY, Gfx.FONT_XTINY]);
    }
}

// mode :retry provar igen på START. mode :back gör inget på START, och BACK går tillbaka.
class MessageDelegate extends Ui.BehaviorDelegate {
    var mode;

    function initialize(m) {
        BehaviorDelegate.initialize();
        mode = m;
    }

    function onSelect() {
        if (mode == :retry) {
            getApp().begin();
        }
        return true;
    }

    function onBack() {
        if (mode == :back) {
            getApp().cancelPass();
        }
        return false;
    }
}

// ---------- Listan med pass ----------

class PassMenuDelegate extends Ui.Menu2InputDelegate {
    function initialize() {
        Menu2InputDelegate.initialize();
    }

    function onSelect(item) {
        getApp().openPass(item.getId());
    }

    function onBack() {
        Ui.popView(Ui.SLIDE_RIGHT);
    }
}

// ---------- Ett pass, innan det startar ----------

class PassView extends Ui.View {
    var pass;

    function initialize(p) {
        View.initialize();
        pass = p;
    }

    function onUpdate(dc) {
        var w = dc.getWidth();
        var h = dc.getHeight();
        var n = pass["items"].size();
        var sub = n + (n == 1 ? " övning" : " övningar");
        if (pass["m"] != null) {
            sub = pass["m"].toNumber() + " min - " + sub;
        }
        dc.setColor(Gfx.COLOR_WHITE, Gfx.COLOR_BLACK);
        dc.clear();
        drawWrapped(dc, pass["n"], Gfx.COLOR_WHITE, (h * 0.18).toNumber(), (h * 0.30).toNumber(), [Gfx.FONT_MEDIUM, Gfx.FONT_SMALL, Gfx.FONT_TINY]);
        dc.setColor(Gfx.COLOR_LT_GRAY, Gfx.COLOR_TRANSPARENT);
        dc.drawText(w / 2, (h * 0.52).toNumber(), Gfx.FONT_TINY, sub, Gfx.TEXT_JUSTIFY_CENTER);
        dc.setColor(ACCENT, Gfx.COLOR_TRANSPARENT);
        dc.drawText(w / 2, (h * 0.70).toNumber(), Gfx.FONT_SMALL, "START startar", Gfx.TEXT_JUSTIFY_CENTER);
    }
}

class PassDelegate extends Ui.BehaviorDelegate {
    var pass;

    function initialize(p) {
        BehaviorDelegate.initialize();
        pass = p;
    }

    function onSelect() {
        getApp().startWorkout(pass);
        return true;
    }
}

// ---------- Passläget ----------

class LiveView extends Ui.View {
    var workout;
    var timer;

    function initialize(w) {
        View.initialize();
        workout = w;
    }

    function onShow() {
        timer = new Timer.Timer();
        timer.start(method(:tick), 1000, true);
    }

    function onHide() {
        if (timer != null) {
            timer.stop();
            timer = null;
        }
    }

    function tick() {
        Ui.requestUpdate();
    }

    function onUpdate(dc) {
        var w = dc.getWidth();
        var h = dc.getHeight();
        var it = workout.current();
        var sets = workout.setCount();
        dc.setColor(Gfx.COLOR_WHITE, Gfx.COLOR_BLACK);
        dc.clear();

        // Var i passet man är
        dc.setColor(Gfx.COLOR_LT_GRAY, Gfx.COLOR_TRANSPARENT);
        dc.drawText(w / 2, (h * 0.07).toNumber(), Gfx.FONT_XTINY, (workout.cur + 1) + " av " + workout.items.size(), Gfx.TEXT_JUSTIFY_CENTER);

        // Övningen och målet
        drawWrapped(dc, it["n"], Gfx.COLOR_WHITE, (h * 0.17).toNumber(), (h * 0.17).toNumber(), [Gfx.FONT_SMALL, Gfx.FONT_TINY, Gfx.FONT_XTINY]);
        var goal = it["g"];
        if (goal == null) {
            goal = "";
        }
        if (sets > 1) {
            goal = "Set " + (workout.setsDone + 1) + " av " + sets + (goal.length() > 0 ? " - " + goal : "");
        }
        dc.setColor(sets > 1 ? GREEN : Gfx.COLOR_LT_GRAY, Gfx.COLOR_TRANSPARENT);
        dc.drawText(w / 2, (h * 0.35).toNumber(), Gfx.FONT_XTINY, goal, Gfx.TEXT_JUSTIFY_CENTER);

        // Övningens tid stort, passets tid under
        dc.setColor(workout.paused() ? Gfx.COLOR_LT_GRAY : Gfx.COLOR_WHITE, Gfx.COLOR_TRANSPARENT);
        dc.drawText(w / 2, (h * 0.44).toNumber(), Gfx.FONT_NUMBER_MEDIUM, fmtTime(workout.exerciseElapsed()), Gfx.TEXT_JUSTIFY_CENTER);
        dc.setColor(Gfx.COLOR_LT_GRAY, Gfx.COLOR_TRANSPARENT);
        dc.drawText(w / 2, (h * 0.70).toNumber(), Gfx.FONT_XTINY, (workout.paused() ? "Pausat " : "Passet ") + fmtTime(workout.elapsed()), Gfx.TEXT_JUSTIFY_CENTER);

        // Vad START gör nu
        var action = workout.paused() ? "BACK: fortsätt" : (workout.moreSets() ? "START: nästa set" : (workout.isLast() ? "START: klar" : "START: nästa"));
        dc.setColor(ACCENT, Gfx.COLOR_TRANSPARENT);
        dc.drawText(w / 2, (h * 0.80).toNumber(), Gfx.FONT_XTINY, action, Gfx.TEXT_JUSTIFY_CENTER);
    }
}

class LiveDelegate extends Ui.BehaviorDelegate {
    var workout;

    function initialize(w) {
        BehaviorDelegate.initialize();
        workout = w;
    }

    function onSelect() {
        workout.advance();
        if (workout.finished) {
            getApp().showSummary();
        } else {
            Ui.requestUpdate();
        }
        return true;
    }

    // BACK och MENU öppnar valen, så att passet inte stängs av misstag.
    function onBack() {
        openActions();
        return true;
    }

    function onMenu() {
        openActions();
        return true;
    }

    function openActions() {
        var menu = new Ui.Menu2({ :title => "Passet" });
        menu.addItem(new Ui.MenuItem(workout.paused() ? "Fortsätt passet" : "Pausa", null, :pause, {}));
        menu.addItem(new Ui.MenuItem("Skippa övningen", null, :skip, {}));
        if (workout.anyDone()) {
            menu.addItem(new Ui.MenuItem("Avsluta och spara", null, :finish, {}));
        }
        menu.addItem(new Ui.MenuItem("Släng passet", null, :discard, {}));
        Ui.pushView(menu, new ActionDelegate(workout), Ui.SLIDE_UP);
    }
}

class ActionDelegate extends Ui.Menu2InputDelegate {
    var workout;

    function initialize(w) {
        Menu2InputDelegate.initialize();
        workout = w;
    }

    function onSelect(item) {
        var what = item.getId();
        // Menyn stängs först, sedan händer valet i vyn under.
        Ui.popView(Ui.SLIDE_IMMEDIATE);
        if (what == :pause) {
            workout.pauseOrResume();
        } else if (what == :skip) {
            workout.skip();
            if (workout.finished) {
                getApp().showSummary();
            }
        } else if (what == :finish) {
            workout.finish();
            getApp().showSummary();
        } else if (what == :discard) {
            getApp().closeWorkout();
        }
        Ui.requestUpdate();
    }

    function onBack() {
        Ui.popView(Ui.SLIDE_DOWN);
    }
}

// ---------- Klart ----------

class SummaryView extends Ui.View {
    var workout;

    function initialize(w) {
        View.initialize();
        workout = w;
    }

    function onUpdate(dc) {
        var w = dc.getWidth();
        var h = dc.getHeight();
        dc.setColor(Gfx.COLOR_WHITE, Gfx.COLOR_BLACK);
        dc.clear();
        dc.setColor(GREEN, Gfx.COLOR_TRANSPARENT);
        dc.drawText(w / 2, (h * 0.12).toNumber(), Gfx.FONT_XTINY, "PASSET ÄR KLART", Gfx.TEXT_JUSTIFY_CENTER);
        dc.setColor(Gfx.COLOR_WHITE, Gfx.COLOR_TRANSPARENT);
        dc.drawText(w / 2, (h * 0.22).toNumber(), Gfx.FONT_NUMBER_MEDIUM, fmtTime(workout.elapsed()), Gfx.TEXT_JUSTIFY_CENTER);
        dc.setColor(Gfx.COLOR_LT_GRAY, Gfx.COLOR_TRANSPARENT);
        dc.drawText(w / 2, (h * 0.50).toNumber(), Gfx.FONT_XTINY, workout.doneCount() + " av " + workout.items.size() + " övningar", Gfx.TEXT_JUSTIFY_CENTER);

        var text;
        var color = Gfx.COLOR_WHITE;
        if (!workout.anyDone()) {
            text = "Du skippade alla övningar, så inget sparas. Tryck START.";
        } else if (workout.sent) {
            text = "Sparat i VARV. Tryck START.";
        } else if (workout.failed) {
            text = "Passet gick inte att spara. Tryck START.";
        } else if (workout.saved) {
            text = "Sparas i VARV. så fort klockan har kontakt. Tryck START.";
        } else {
            text = "START sparar passet";
            color = ACCENT;
        }
        drawWrapped(dc, text, color, (h * 0.60).toNumber(), (h * 0.28).toNumber(), [Gfx.FONT_TINY, Gfx.FONT_XTINY]);
    }
}

class SummaryDelegate extends Ui.BehaviorDelegate {
    function initialize() {
        BehaviorDelegate.initialize();
    }

    function onSelect() {
        var app = getApp();
        var w = app.workout;
        if (w == null) {
            return true;
        }
        if (w.anyDone() && !w.saved) {
            app.saveWorkout();
            Ui.requestUpdate();
        } else {
            app.closeWorkout();
        }
        return true;
    }

    // Ett pass som inte är sparat stängs inte av misstag: BACK frågar först.
    function onBack() {
        var app = getApp();
        var w = app.workout;
        if (w == null || !w.anyDone() || w.saved) {
            app.closeWorkout();
            return true;
        }
        var menu = new Ui.Menu2({ :title => "Passet" });
        menu.addItem(new Ui.MenuItem("Spara", null, :save, {}));
        menu.addItem(new Ui.MenuItem("Släng passet", null, :discard, {}));
        Ui.pushView(menu, new SummaryMenuDelegate(), Ui.SLIDE_UP);
        return true;
    }
}

class SummaryMenuDelegate extends Ui.Menu2InputDelegate {
    function initialize() {
        Menu2InputDelegate.initialize();
    }

    function onSelect(item) {
        var what = item.getId();
        Ui.popView(Ui.SLIDE_IMMEDIATE);
        if (what == :save) {
            getApp().saveWorkout();
        } else {
            getApp().closeWorkout();
        }
        Ui.requestUpdate();
    }

    function onBack() {
        Ui.popView(Ui.SLIDE_DOWN);
    }
}
