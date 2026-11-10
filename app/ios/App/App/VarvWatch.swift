import Foundation
import Capacitor
import WatchConnectivity

/// Bryggan mellan appen och VARV. på Apple Watch.
/// Appen frågar om det finns en klocka med VARV. installerat och lämnar över klockans nyckel.
/// Själva passen hämtar och sparar klockan sedan själv mot kontot.
@objc(VarvWatchPlugin)
public class VarvWatchPlugin: CAPPlugin, CAPBridgedPlugin, WCSessionDelegate {
    public let identifier = "VarvWatchPlugin"
    public let jsName = "VarvWatch"
    public let pluginMethods: [CAPPluginMethod] = [
        CAPPluginMethod(name: "status", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "link", returnType: CAPPluginReturnPromise)
    ]

    /// Anrop som väntar på att kontakten med klockan ska komma igång.
    private var waiting: [CAPPluginCall] = []

    override public func load() {
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        session.delegate = self
        session.activate()
    }

    private func statusData() -> [String: Any] {
        guard WCSession.isSupported() else {
            return ["supported": false, "paired": false, "installed": false]
        }
        let session = WCSession.default
        return ["supported": true, "paired": session.isPaired, "installed": session.isWatchAppInstalled]
    }

    @objc func status(_ call: CAPPluginCall) {
        DispatchQueue.main.async {
            if !WCSession.isSupported() || WCSession.default.activationState == .activated {
                call.resolve(self.statusData())
            } else {
                self.waiting.append(call)
                WCSession.default.activate()
            }
        }
    }

    /// Lämnar över nyckeln till klockan. En tom nyckel kopplar bort klockan.
    @objc func link(_ call: CAPPluginCall) {
        guard WCSession.isSupported() else {
            call.reject("Telefonen har inget stöd för Apple Watch")
            return
        }
        let context: [String: Any] = [
            "token": call.getString("token") ?? "",
            "url": call.getString("url") ?? "",
            "key": call.getString("key") ?? "",
            "at": Date().timeIntervalSince1970
        ]
        DispatchQueue.main.async {
            let session = WCSession.default
            guard session.activationState == .activated else {
                call.reject("Klockan är inte redo än")
                return
            }
            do {
                try session.updateApplicationContext(context)
                call.resolve(["sent": true])
            } catch {
                call.reject("Nyckeln gick inte att skicka till klockan")
            }
        }
    }

    // MARK: WCSessionDelegate

    public func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        DispatchQueue.main.async {
            let calls = self.waiting
            self.waiting = []
            let data = self.statusData()
            calls.forEach { $0.resolve(data) }
        }
    }

    public func sessionDidBecomeInactive(_ session: WCSession) {}

    public func sessionDidDeactivate(_ session: WCSession) {
        // Användaren har bytt klocka: starta om kontakten mot den nya.
        session.activate()
    }

    /// Klockan frågar efter nyckeln när den saknar en, till exempel direkt efter installationen.
    public func session(_ session: WCSession, didReceiveMessage message: [String: Any], replyHandler: @escaping ([String: Any]) -> Void) {
        replyHandler(session.applicationContext)
    }
}
