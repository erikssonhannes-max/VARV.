import Foundation
import Capacitor
import HealthKit

/// Läser träningspass från Apple Hälsa, så att pass från andra klockor kommer in i VARV.
/// VARV. skriver aldrig något till Hälsa.
@objc(VarvHealthPlugin)
public class VarvHealthPlugin: CAPPlugin, CAPBridgedPlugin {
    public let identifier = "VarvHealthPlugin"
    public let jsName = "VarvHealth"
    public let pluginMethods: [CAPPluginMethod] = [
        CAPPluginMethod(name: "available", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "authorize", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "workouts", returnType: CAPPluginReturnPromise)
    ]

    private let store = HKHealthStore()

    private var readTypes: Set<HKObjectType> {
        var types: Set<HKObjectType> = [HKObjectType.workoutType()]
        if let hr = HKObjectType.quantityType(forIdentifier: .heartRate) { types.insert(hr) }
        return types
    }

    @objc func available(_ call: CAPPluginCall) {
        call.resolve(["available": HKHealthStore.isHealthDataAvailable()])
    }

    /// Visar iOS egen fråga om att läsa träningspass och puls. Frågan visas bara första gången.
    @objc func authorize(_ call: CAPPluginCall) {
        guard HKHealthStore.isHealthDataAvailable() else {
            call.reject("Hälsa finns inte på den här enheten")
            return
        }
        store.requestAuthorization(toShare: nil, read: readTypes) { ok, error in
            if ok {
                call.resolve(["asked": true])
            } else {
                call.reject(error?.localizedDescription ?? "Ingen åtkomst till Hälsa")
            }
        }
    }

    /// Träningspass sedan ett datum, nyast först. iOS säger aldrig om läsningen nekades,
    /// så en tom lista kan betyda både inga pass och ingen åtkomst.
    @objc func workouts(_ call: CAPPluginCall) {
        guard HKHealthStore.isHealthDataAvailable() else {
            call.resolve(["workouts": []])
            return
        }
        let sinceMs = call.getDouble("since") ?? (Date().addingTimeInterval(-56 * 86400).timeIntervalSince1970 * 1000)
        let since = Date(timeIntervalSince1970: sinceMs / 1000)
        let limit = min(max(call.getInt("limit") ?? 100, 1), 200)
        let predicate = HKQuery.predicateForSamples(withStart: since, end: Date(), options: .strictStartDate)
        let sort = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)

        let query = HKSampleQuery(sampleType: HKObjectType.workoutType(), predicate: predicate, limit: limit, sortDescriptors: [sort]) { [weak self] _, samples, error in
            guard let self = self else { return }
            if error != nil {
                call.resolve(["workouts": []])
                return
            }
            let list = (samples as? [HKWorkout]) ?? []
            self.withHeartRates(list) { rates in
                let out: [[String: Any]] = list.map { w in
                    var o: [String: Any] = [
                        "id": w.uuid.uuidString.lowercased(),
                        "start": w.startDate.timeIntervalSince1970 * 1000,
                        "end": w.endDate.timeIntervalSince1970 * 1000,
                        "duration": w.duration,
                        "type": Int(w.workoutActivityType.rawValue),
                        "source": w.sourceRevision.source.name,
                        "bundle": w.sourceRevision.source.bundleIdentifier
                    ]
                    if let d = w.totalDistance?.doubleValue(for: .meter()), d > 0 { o["meters"] = d }
                    if let e = w.totalEnergyBurned?.doubleValue(for: .kilocalorie()), e > 0 { o["kcal"] = e }
                    if let hr = rates[w.uuid] { o["hr"] = hr }
                    return o
                }
                call.resolve(["workouts": out])
            }
        }
        store.execute(query)
    }

    /// Snittpulsen under varje pass, för de pass där klockan har sparat puls i Hälsa.
    private func withHeartRates(_ workouts: [HKWorkout], done: @escaping ([UUID: Int]) -> Void) {
        guard let type = HKQuantityType.quantityType(forIdentifier: .heartRate), !workouts.isEmpty else {
            done([:])
            return
        }
        let unit = HKUnit.count().unitDivided(by: .minute())
        let group = DispatchGroup()
        let lock = NSLock()
        var rates: [UUID: Int] = [:]
        for w in workouts {
            group.enter()
            let predicate = HKQuery.predicateForSamples(withStart: w.startDate, end: w.endDate, options: .strictStartDate)
            let q = HKStatisticsQuery(quantityType: type, quantitySamplePredicate: predicate, options: .discreteAverage) { _, stats, _ in
                if let v = stats?.averageQuantity()?.doubleValue(for: unit), v > 0 {
                    lock.lock()
                    rates[w.uuid] = Int(v.rounded())
                    lock.unlock()
                }
                group.leave()
            }
            store.execute(q)
        }
        group.notify(queue: .main) { done(rates) }
    }
}
