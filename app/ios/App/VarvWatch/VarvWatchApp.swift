import SwiftUI

/// VARV. på Apple Watch: välj ett förberett eller färdigt pass, kör det och spara det i kontot.
@main
struct VarvWatchApp: App {
    @StateObject private var store = Store.shared
    @StateObject private var app = AppState()
    @Environment(\.scenePhase) private var phase

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(store)
                .environmentObject(app)
                .tint(Brand.accent)
                .task {
                    if store.link == nil { store.askPhone() }
                    await store.refresh()
                    await store.flush()
                }
                .onChange(of: phase) { _, new in
                    guard new == .active else { return }
                    if store.link == nil { store.askPhone() }
                    Task { await store.refresh(); await store.flush() }
                }
        }
    }
}

/// Vilket pass som körs just nu.
final class AppState: ObservableObject {
    @Published var workout: Workout? = Workout.restore()

    func start(_ pass: WPass) {
        workout = Workout(pass: pass)
    }

    func close() {
        Workout.clear()
        workout = nil
    }
}

enum Brand {
    /// VARV.:s rosa, samma som accent i mörkt tema.
    static let accent = Color(red: 1, green: 45 / 255, blue: 85 / 255)
    /// Grönt för stationer och avklarat.
    static let green = Color(red: 48 / 255, green: 209 / 255, blue: 88 / 255)
}

struct RootView: View {
    @EnvironmentObject private var store: Store
    @EnvironmentObject private var app: AppState

    var body: some View {
        if let workout = app.workout {
            WorkoutView(workout: workout)
        } else if store.link == nil {
            NotLinkedView()
        } else {
            PassListView()
        }
    }
}

/// Passet som pågår: passläget tills allt är klart, sedan sammanfattningen.
struct WorkoutView: View {
    @ObservedObject var workout: Workout

    var body: some View {
        if workout.finished {
            SummaryView(workout: workout)
        } else {
            LiveView(workout: workout)
        }
    }
}
