import SwiftUI

// MARK: Inte kopplad

struct NotLinkedView: View {
    @EnvironmentObject private var store: Store

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                Text("VARV.")
                    .font(.title2.weight(.bold))
                Text("Öppna VARV. på din iPhone och logga in, så kopplas klockan av sig själv.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                Button("Försök igen") { store.askPhone() }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 4)
        }
    }
}

// MARK: Passen

struct PassListView: View {
    @EnvironmentObject private var store: Store

    private struct PassGroup: Identifiable {
        let name: String
        let passes: [WPass]
        var id: String { name }
    }

    private var groups: [PassGroup] {
        var order: [String] = []
        var map: [String: [WPass]] = [:]
        for p in store.passes {
            let g = p.g ?? "Pass"
            if map[g] == nil { order.append(g) }
            map[g, default: []].append(p)
        }
        return order.map { PassGroup(name: $0, passes: map[$0] ?? []) }
    }

    var body: some View {
        NavigationStack {
            List {
                if !store.pending.isEmpty {
                    Text(store.pending.count == 1 ? "1 pass väntar på att sparas" : "\(store.pending.count) pass väntar på att sparas")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                if store.passes.isEmpty {
                    Text(store.problem ?? (store.loading ? "Hämtar dina pass…" : "Inga pass än. Öppna VARV. på telefonen en gång, så skickas passen hit."))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                ForEach(groups) { group in
                    Section(group.name) {
                        ForEach(group.passes) { pass in
                            NavigationLink(value: pass) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(pass.n).font(.headline)
                                    Text(PassListView.subtitle(pass))
                                        .font(.footnote)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }
                Button {
                    Task { await store.refresh(); await store.flush() }
                } label: {
                    Label(store.loading ? "Hämtar…" : "Uppdatera", systemImage: "arrow.clockwise")
                }
                .disabled(store.loading)
            }
            .navigationTitle("VARV.")
            .navigationDestination(for: WPass.self) { PassDetailView(pass: $0) }
        }
    }

    static func subtitle(_ pass: WPass) -> String {
        var p: [String] = []
        if let m = pass.m, m > 0 { p.append("\(Int(m)) min") }
        p.append(pass.items.count == 1 ? "1 övning" : "\(pass.items.count) övningar")
        return p.joined(separator: " · ")
    }
}

struct PassDetailView: View {
    @EnvironmentObject private var app: AppState
    let pass: WPass

    var body: some View {
        List {
            Section {
                Button {
                    app.start(pass)
                } label: {
                    Text("Starta")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                }
                .listRowBackground(RoundedRectangle(cornerRadius: 12).fill(Brand.accent))
                .foregroundStyle(.white)
            } footer: {
                if let h = pass.h, !h.isEmpty { Text(h) }
            }
            Section(PassListView.subtitle(pass)) {
                ForEach(Array(pass.items.enumerated()), id: \.offset) { _, item in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.n)
                        if let g = item.g, !g.isEmpty {
                            Text(g).font(.footnote).foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .navigationTitle(pass.n)
    }
}

// MARK: Passläget

struct LiveView: View {
    @EnvironmentObject private var app: AppState
    @ObservedObject var workout: Workout
    @State private var asking = false

    private var title: String {
        let mixed = workout.steps.contains { $0.item.isRun } && workout.steps.contains { !$0.item.isRun }
        return "\(mixed ? "Moment" : "Övning") \(workout.cur + 1) av \(workout.steps.count)"
    }

    /// Det som ska göras nu: setets mål, eller hela övningens om den bara har ett set.
    private var goal: String {
        guard let item = workout.current else { return "" }
        if workout.setCount > 1, let s = workout.currentSet {
            let t = Fmt.set(item.k, s)
            if !t.isEmpty { return t }
        }
        return item.g ?? ""
    }

    private var action: String {
        if workout.moreSets { return "Nästa set" }
        return workout.isLast ? "Klar" : "Nästa"
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 6) {
                Text(title.uppercased())
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
                Text(workout.current?.n ?? "")
                    .font(.title3.weight(.semibold))
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.7)
                if !goal.isEmpty {
                    Text(goal)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                if workout.setCount > 1 {
                    Text("Set \(workout.setsDone + 1) av \(workout.setCount)")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(Brand.green)
                }
                clock
                Button(action: workout.advance) {
                    Text(action)
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(Brand.accent)
                .disabled(workout.paused)
                if let next = workout.next, !workout.moreSets {
                    Text("Sedan: \(next.n)")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                HStack(spacing: 6) {
                    Button(action: workout.pauseOrResume) {
                        Image(systemName: workout.paused ? "play.fill" : "pause.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .accessibilityLabel(workout.paused ? "Fortsätt" : "Pausa")
                    Button(action: workout.skip) {
                        Image(systemName: "forward.end.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .accessibilityLabel("Skippa övningen")
                    Button { asking = true } label: {
                        Image(systemName: "xmark")
                            .frame(maxWidth: .infinity)
                    }
                    .accessibilityLabel("Avsluta passet")
                }
                .buttonStyle(.bordered)
                .padding(.top, 4)
            }
            .padding(.horizontal, 2)
        }
        .confirmationDialog("Avsluta passet?", isPresented: $asking, titleVisibility: .visible) {
            if workout.anyDone {
                Button("Avsluta och spara") { workout.finish() }
            }
            Button("Släng passet", role: .destructive) { app.close() }
            Button("Fortsätt", role: .cancel) {}
        }
    }

    /// Övningens tid stort, passets tid under. Systemet ritar klockorna, så de går även när armen är nere.
    @ViewBuilder private var clock: some View {
        VStack(spacing: 0) {
            Group {
                if workout.paused {
                    Text(Fmt.time(workout.exerciseElapsed()))
                } else {
                    Text(workout.exerciseStart, style: .timer)
                }
            }
            .font(.system(size: 40, weight: .bold, design: .rounded))
            .monospacedDigit()
            .foregroundStyle(workout.paused ? Color.secondary : Color.primary)
            HStack(spacing: 4) {
                Text(workout.paused ? "Pausat" : "Passet")
                if workout.paused {
                    Text(Fmt.time(workout.elapsed()))
                } else {
                    Text(workout.totalStart, style: .timer)
                }
            }
            .font(.footnote)
            .monospacedDigit()
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
    }
}

// MARK: Klart

struct SummaryView: View {
    @EnvironmentObject private var store: Store
    @EnvironmentObject private var app: AppState
    @ObservedObject var workout: Workout
    @State private var saving = false
    @State private var saved = false

    var body: some View {
        ScrollView {
            VStack(spacing: 8) {
                Text("PASSET ÄR KLART")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(Brand.green)
                Text(Fmt.time(workout.elapsed()))
                    .font(.system(size: 40, weight: .bold, design: .rounded))
                    .monospacedDigit()
                Text("\(workout.pass.n) · \(workout.doneCount) av \(workout.steps.count) övningar")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                if saved {
                    Text(store.pending.isEmpty ? "Sparat i VARV." : "Sparas i VARV. så fort klockan har nät.")
                        .font(.footnote)
                        .multilineTextAlignment(.center)
                    Button("Klar") { app.close() }
                        .buttonStyle(.borderedProminent)
                        .tint(Brand.accent)
                } else if workout.anyDone {
                    Button {
                        saving = true
                        let r = workout.result()
                        Task {
                            await store.save(id: r.id, pass: r.pass)
                            saving = false
                            saved = true
                        }
                    } label: {
                        Text(saving ? "Sparar…" : "Spara")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Brand.accent)
                    .disabled(saving)
                    Button("Släng passet", role: .destructive) { app.close() }
                        .disabled(saving)
                } else {
                    Text("Du skippade alla övningar, så inget sparas.")
                        .font(.footnote)
                        .multilineTextAlignment(.center)
                    Button("Stäng") { app.close() }
                }
            }
            .padding(.horizontal, 2)
        }
    }
}
