import UIKit
import Capacitor
import EventKit
import EventKitUI

/// Startskärmen för appen. Den registrerar VARV.:s egna insticksmoduler.
class MainViewController: CAPBridgeViewController {
    override open func capacitorDidLoad() {
        bridge?.registerPluginInstance(VarvCalendarPlugin())
    }
}

/// Öppnar iOS egen ruta för att lägga till ett lopp i Kalender, utan att lämna appen.
@objc(VarvCalendarPlugin)
public class VarvCalendarPlugin: CAPPlugin, CAPBridgedPlugin, EKEventEditViewDelegate {
    public let identifier = "VarvCalendarPlugin"
    public let jsName = "VarvCalendar"
    public let pluginMethods: [CAPPluginMethod] = [
        CAPPluginMethod(name: "addEvent", returnType: CAPPluginReturnPromise)
    ]

    private let store = EKEventStore()
    private var pendingCall: CAPPluginCall?

    @objc func addEvent(_ call: CAPPluginCall) {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        guard let title = call.getString("title"),
              let startText = call.getString("start"),
              let start = formatter.date(from: startText) else {
            call.reject("Uppgifter saknas")
            return
        }
        let end = formatter.date(from: call.getString("end") ?? startText) ?? start

        let present = { [weak self] in
            DispatchQueue.main.async {
                guard let self = self, let host = self.bridge?.viewController else {
                    call.reject("Kalendern gick inte att öppna")
                    return
                }
                let event = EKEvent(eventStore: self.store)
                event.title = title
                event.isAllDay = true
                event.startDate = start
                event.endDate = end
                event.availability = .free
                event.location = call.getString("location")
                event.notes = call.getString("notes")
                if let link = call.getString("url") {
                    event.url = URL(string: link)
                }
                let editor = EKEventEditViewController()
                editor.eventStore = self.store
                editor.event = event
                editor.editViewDelegate = self
                self.pendingCall = call
                host.present(editor, animated: true)
            }
        }

        if #available(iOS 17.0, *) {
            // Från iOS 17 körs rutan utanför appen och kräver ingen behörighet.
            present()
        } else {
            store.requestAccess(to: .event) { granted, _ in
                if granted {
                    present()
                } else {
                    call.reject("Ingen åtkomst till Kalender")
                }
            }
        }
    }

    public func eventEditViewController(_ controller: EKEventEditViewController, didCompleteWith action: EKEventEditViewAction) {
        controller.dismiss(animated: true)
        pendingCall?.resolve(["saved": action == .saved])
        pendingCall = nil
    }
}
