import Foundation

/// Ett set i en övning. Samma fält som appen sparar: meter, reps, kcal, tid i sekunder och kilo.
struct WSet: Codable, Hashable {
    var m: Double?
    var r: Double?
    var c: Double?
    var t: Double?
    var kg: Double?
}

/// En övning i ett pass, så som appen publicerar den till klockan.
struct WItem: Codable, Hashable {
    var ex: String
    var n: String
    var k: String
    var w: Int
    var st: Int
    var g: String?
    var sets: [WSet]

    /// Övningar där tiden är en del av resultatet: sträckor, kalorier, tidsövningar och stationer.
    var timed: Bool { k == "d" || k == "c" || k == "t" || (k == "r" && st == 1) }
    var isRun: Bool { ex == "run" || ex == "tread" }
}

/// Ett pass som går att starta från klockan.
struct WPass: Codable, Hashable, Identifiable {
    var id: String
    var n: String
    var t: String?
    var m: Double?
    var g: String?
    var h: String?
    var items: [WItem]
}

struct WPlan: Codable {
    var updated: String?
    var passes: [WPass]
}

/// Kopplingen till kontot, som telefonen lämnar över.
struct WLink: Codable, Equatable {
    var token: String
    var url: String
    var key: String
}

/// Ett färdigt pass som väntar på att sparas i kontot.
struct WPending: Codable, Identifiable {
    var id: String
    var body: Data
}

enum Fmt {
    /// 754 → "12:34", 3723 → "1:02:03"
    static func time(_ seconds: Double) -> String {
        let s = max(0, Int(seconds.rounded()))
        let h = s / 3600, m = (s % 3600) / 60, r = s % 60
        let two: (Int) -> String = { $0 < 10 ? "0\($0)" : "\($0)" }
        return h > 0 ? "\(h):\(two(m)):\(two(r))" : "\(m):\(two(r))"
    }

    static func number(_ v: Double) -> String {
        let r = (v * 10).rounded() / 10
        if r == r.rounded() { return String(Int(r)) }
        return String(r).replacingOccurrences(of: ".", with: ",")
    }

    static func meters(_ m: Double) -> String {
        if m >= 2000 && m.truncatingRemainder(dividingBy: 100) == 0 { return number(m / 1000) + " km" }
        return number(m) + " m"
    }

    /// Texten för ett set, på samma sätt som i appen: "60 kg × 8", "1000 m", "30 kcal".
    static func set(_ k: String, _ s: WSet) -> String {
        var p: [String] = []
        let pos: (Double?) -> Double? = { v in (v ?? 0) > 0 ? v : nil }
        if k == "d" {
            if let m = pos(s.m) { p.append(meters(m)) }
            if let t = pos(s.t) { p.append(time(t)) }
        } else if k == "r" {
            if let kg = pos(s.kg), let r = pos(s.r) { return number(kg) + " kg × " + number(r) }
            if let r = pos(s.r) { p.append(number(r) + " reps") }
        } else if k == "c" {
            if let c = pos(s.c) { p.append(number(c) + " kcal") }
            if let t = pos(s.t) { p.append(time(t)) }
        } else if let t = pos(s.t) {
            p.append(time(t))
        }
        if let kg = pos(s.kg) { p.append(number(kg) + " kg") }
        return p.joined(separator: " · ")
    }
}
