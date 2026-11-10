import Foundation
import WatchConnectivity

/// Håller kopplingen till kontot, listan med pass och kön med pass som ska sparas.
/// Klockan pratar själv med kontot. Telefonen behövs bara för att lämna över nyckeln.
final class Store: NSObject, ObservableObject, WCSessionDelegate {
    static let shared = Store()

    @Published var link: WLink?
    @Published var passes: [WPass] = []
    @Published var loading = false
    @Published var problem: String?
    @Published var pending: [WPending] = []

    private let defaults = UserDefaults.standard
    private var flushing = false

    private enum Key {
        static let link = "varv.link"
        static let plan = "varv.plan"
        static let pending = "varv.pending"
        static let rejected = "varv.rejected"
    }

    override init() {
        super.init()
        if let d = defaults.data(forKey: Key.link), let l = try? JSONDecoder().decode(WLink.self, from: d) { link = l }
        if let d = defaults.data(forKey: Key.plan), let p = try? JSONDecoder().decode(WPlan.self, from: d) { passes = p.passes }
        if let d = defaults.data(forKey: Key.pending), let p = try? JSONDecoder().decode([WPending].self, from: d) { pending = p }
        if WCSession.isSupported() {
            WCSession.default.delegate = self
            WCSession.default.activate()
        }
    }

    // MARK: Kopplingen

    /// Tar emot nyckeln från telefonen. En tom nyckel betyder att klockan har kopplats bort.
    private func apply(_ context: [String: Any]) {
        let token = context["token"] as? String ?? ""
        let url = context["url"] as? String ?? ""
        let key = context["key"] as? String ?? ""
        DispatchQueue.main.async {
            if token.isEmpty {
                if context["at"] != nil { self.unlink(rejected: nil) }
                return
            }
            // En nyckel som kontot redan har avvisat provas inte igen.
            if token == self.defaults.string(forKey: Key.rejected) { return }
            let new = WLink(token: token, url: url, key: key)
            if new == self.link { return }
            self.link = new
            if let d = try? JSONEncoder().encode(new) { self.defaults.set(d, forKey: Key.link) }
            Task { await self.refresh(); await self.flush() }
        }
    }

    private func unlink(rejected: String?) {
        link = nil
        passes = []
        defaults.removeObject(forKey: Key.link)
        defaults.removeObject(forKey: Key.plan)
        if let r = rejected { defaults.set(r, forKey: Key.rejected) }
    }

    /// Frågar telefonen efter nyckeln. Används när klockan inte är kopplad.
    func askPhone() {
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        guard session.activationState == .activated else { session.activate(); return }
        apply(session.receivedApplicationContext)
        if session.isReachable {
            session.sendMessage(["hello": 1], replyHandler: { reply in self.apply(reply) }, errorHandler: { _ in })
        }
    }

    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        apply(session.receivedApplicationContext)
    }

    func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        apply(applicationContext)
    }

    // MARK: Anrop mot kontot

    /// rejected: nyckeln gäller inte längre. invalid: kontot tog inte emot innehållet. failed: inget nät eller tillfälligt fel.
    private enum CallError: Error { case notLinked, rejected, invalid, failed }

    private func call(_ link: WLink?, _ function: String, _ body: [String: Any]) async throws -> Data {
        guard let link = link, let url = URL(string: link.url + "/rest/v1/rpc/" + function) else { throw CallError.notLinked }
        var args = body
        args["p_token"] = link.token
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 20
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(link.key, forHTTPHeaderField: "apikey")
        request.setValue("Bearer " + link.key, forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONSerialization.data(withJSONObject: args)
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw CallError.failed }
        if http.statusCode == 401 || http.statusCode == 403 {
            // Kontot känner inte igen nyckeln: klockan har kopplats bort i appen.
            let token = link.token
            await MainActor.run { if self.link?.token == token { self.unlink(rejected: token) } }
            throw CallError.rejected
        }
        if http.statusCode == 400 || http.statusCode == 404 || http.statusCode == 413 || http.statusCode == 422 { throw CallError.invalid }
        guard (200..<300).contains(http.statusCode) else { throw CallError.failed }
        return data
    }

    /// Hämtar passen från kontot. Utan nät visas de som hämtades senast.
    @MainActor
    func refresh() async {
        guard link != nil, !loading else { return }
        loading = true
        defer { loading = false }
        do {
            let data = try await call(link, "watch_passes", [:])
            let plan = try JSONDecoder().decode(WPlan.self, from: data)
            passes = plan.passes
            defaults.set(data, forKey: Key.plan)
            problem = nil
        } catch CallError.rejected {
            problem = nil
        } catch {
            problem = passes.isEmpty ? "Passen gick inte att hämta. Kontrollera att klockan har nät." : nil
        }
    }

    // MARK: Spara pass

    /// Lägger passet i kön och försöker spara det direkt.
    @MainActor
    func save(id: String, pass: [String: Any]) async {
        guard let body = try? JSONSerialization.data(withJSONObject: pass) else { return }
        pending.append(WPending(id: id, body: body))
        storePending()
        await flush()
    }

    private func storePending() {
        if let d = try? JSONEncoder().encode(pending) { defaults.set(d, forKey: Key.pending) }
    }

    /// Skickar allt som väntar. Det som inte går fram ligger kvar till nästa gång.
    @MainActor
    func flush() async {
        guard link != nil, !flushing, !pending.isEmpty else { return }
        flushing = true
        defer { flushing = false }
        for item in pending {
            guard let pass = try? JSONSerialization.jsonObject(with: item.body) else {
                pending.removeAll { $0.id == item.id }
                continue
            }
            do {
                _ = try await call(link, "watch_log", ["p_id": item.id, "p_pass": pass])
                pending.removeAll { $0.id == item.id }
            } catch CallError.invalid {
                // Kontot tar inte emot passet hur många gånger det än skickas, så det får inte stoppa kön.
                pending.removeAll { $0.id == item.id }
            } catch {
                break
            }
        }
        storePending()
    }
}
