import Foundation
import WatchKit

/// Ett pass som körs på klockan. Följer samma regler som passläget i appen:
/// en övning med flera set går set för set, tiden sparas på övningar där tiden betyder något,
/// och en skippad övning sparas inte.
final class Workout: ObservableObject {
    struct Step: Codable {
        var item: WItem
        var done = false
        var skipped = false
        var sec: Double?
    }

    /// Allt som behövs för att fortsätta passet om klockan stänger appen.
    struct Snapshot: Codable {
        var pass: WPass
        var steps: [Step]
        var cur: Int
        var setsDone: Int
        var startedAt: Date
        var pausedTotal: Double
        var pausedAt: Date?
        var exAt: Double
        var finished: Bool
        var uid: String
    }

    private static let key = "varv.workout"

    @Published private(set) var pass: WPass
    @Published private(set) var steps: [Step]
    @Published private(set) var cur = 0
    @Published private(set) var setsDone = 0
    @Published private(set) var pausedAt: Date?
    @Published private(set) var finished = false
    private(set) var startedAt = Date()
    private(set) var pausedTotal: Double = 0
    /// Passets tid när den pågående övningen började.
    private(set) var exAt: Double = 0
    /// Passets id i loggen. Samma id varje gång passet skickas, så att det bara sparas en gång.
    private(set) var uid: String = Workout.newId()

    private static func newId() -> String {
        let stamp = String(Int64(Date().timeIntervalSince1970 * 1000), radix: 36)
        let random = String(Int.random(in: 0..<1_679_616), radix: 36)
        return "w" + stamp + random
    }

    init(pass: WPass) {
        self.pass = pass
        self.steps = pass.items.map { Step(item: $0) }
        persist()
        WKInterfaceDevice.current().play(.start)
    }

    private init(snapshot s: Snapshot) {
        pass = s.pass
        steps = s.steps
        cur = min(max(0, s.cur), max(0, s.steps.count - 1))
        setsDone = s.setsDone
        startedAt = s.startedAt
        pausedTotal = s.pausedTotal
        pausedAt = s.pausedAt
        exAt = s.exAt
        finished = s.finished
        uid = s.uid
    }

    /// Passet som pågick när appen stängdes, om det finns något.
    static func restore() -> Workout? {
        guard let d = UserDefaults.standard.data(forKey: key),
              let s = try? JSONDecoder().decode(Snapshot.self, from: d), !s.steps.isEmpty else { return nil }
        // Ett pass som har legat i över ett dygn fortsätter man inte.
        if Date().timeIntervalSince(s.startedAt) > 24 * 3600 { clear(); return nil }
        return Workout(snapshot: s)
    }

    static func clear() { UserDefaults.standard.removeObject(forKey: key) }

    private func persist() {
        let s = Snapshot(pass: pass, steps: steps, cur: cur, setsDone: setsDone, startedAt: startedAt,
                         pausedTotal: pausedTotal, pausedAt: pausedAt, exAt: exAt, finished: finished, uid: uid)
        if let d = try? JSONEncoder().encode(s) { UserDefaults.standard.set(d, forKey: Workout.key) }
    }

    // MARK: Tid

    var paused: Bool { pausedAt != nil }

    /// Passets tid, utan pauser.
    func elapsed(_ now: Date = Date()) -> Double {
        max(0, (pausedAt ?? now).timeIntervalSince(startedAt) - pausedTotal)
    }

    /// Tiden i den pågående övningen.
    func exerciseElapsed(_ now: Date = Date()) -> Double { max(0, elapsed(now) - exAt) }

    /// Tidpunkten som passets klocka räknar från, så att systemet kan rita en löpande klocka.
    var totalStart: Date { startedAt.addingTimeInterval(pausedTotal) }
    var exerciseStart: Date { totalStart.addingTimeInterval(exAt) }

    // MARK: Läge

    var current: WItem? { steps.indices.contains(cur) ? steps[cur].item : nil }
    var next: WItem? { steps.indices.contains(cur + 1) ? steps[cur + 1].item : nil }
    var isLast: Bool { cur >= steps.count - 1 }
    var setCount: Int { current?.sets.count ?? 0 }
    var moreSets: Bool { setCount > 1 && setsDone < setCount - 1 }
    var anyDone: Bool { steps.contains { $0.done } }
    var doneCount: Int { steps.filter { $0.done }.count }

    /// Setet som ska göras nu.
    var currentSet: WSet? {
        guard let it = current, !it.sets.isEmpty else { return nil }
        return it.sets[min(setsDone, it.sets.count - 1)]
    }

    // MARK: Steg

    func pauseOrResume() {
        if let p = pausedAt {
            pausedTotal += Date().timeIntervalSince(p)
            pausedAt = nil
        } else {
            pausedAt = Date()
        }
        WKInterfaceDevice.current().play(.click)
        persist()
    }

    /// Nästa set, eller nästa övning när sista setet är klart.
    func advance() {
        guard !finished, steps.indices.contains(cur) else { return }
        if moreSets {
            setsDone += 1
            WKInterfaceDevice.current().play(.click)
            persist()
            return
        }
        let sec = max(1, exerciseElapsed().rounded())
        steps[cur].done = true
        if steps[cur].item.timed {
            steps[cur].sec = sec
            // En ensam sträcka eller station får sin tid direkt i setet, som i appen.
            if steps[cur].item.sets.count == 1 { steps[cur].item.sets[0].t = sec }
        }
        step()
    }

    /// Hoppar över övningen. Den sparas inte med passet.
    func skip() {
        guard !finished, steps.indices.contains(cur) else { return }
        steps[cur].skipped = true
        step()
    }

    private func step() {
        if isLast {
            finish()
            return
        }
        cur += 1
        setsDone = 0
        exAt = elapsed()
        WKInterfaceDevice.current().play(.success)
        persist()
    }

    /// Avslutar passet där det är. Det som är klart går att spara.
    func finish() {
        if pausedAt == nil { pausedAt = Date() }
        finished = true
        WKInterfaceDevice.current().play(.success)
        persist()
    }

    // MARK: Resultat

    /// Passet i den form som kontot tar emot. Bara övningar som blev klara följer med.
    func result() -> (id: String, pass: [String: Any]) {
        let day = DateFormatter()
        day.locale = Locale(identifier: "en_US_POSIX")
        day.dateFormat = "yyyy-MM-dd"
        let items: [[String: Any]] = steps.filter { $0.done }.map { s in
            var o: [String: Any] = ["ex": s.item.ex, "n": s.item.n, "k": s.item.k, "w": s.item.w, "st": s.item.st]
            if let sec = s.sec { o["sec"] = Int(sec) }
            o["sets"] = s.item.sets.map { x -> [String: Any] in
                var d: [String: Any] = [:]
                if let v = x.m, v > 0 { d["m"] = v }
                if let v = x.r, v > 0 { d["r"] = v }
                if let v = x.c, v > 0 { d["c"] = v }
                if let v = x.t, v > 0 { d["t"] = v }
                if let v = x.kg, v > 0 { d["kg"] = v }
                return d
            }
            return o
        }
        var body: [String: Any] = [
            "date": day.string(from: startedAt),
            "total": Int(elapsed()),
            "name": pass.n,
            "items": items
        ]
        if let t = pass.t, !t.isEmpty { body["type"] = t }
        return (uid, body)
    }
}
