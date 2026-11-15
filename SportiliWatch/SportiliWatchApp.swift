import SwiftUI

@main
struct SportiliWatchApp: App {
    @StateObject private var store = WatchWorkoutStore(fixture: Self.useFixture)
    @Environment(\.scenePhase) private var phase
    var body: some Scene {
        WindowGroup {
            entryView.environmentObject(store).tint(WatchStyle.accent)
                .id((store.state.sync.snapshot?.binding ?? "") + (store.state.sync.snapshot?.workoutRevision ?? ""))
                .onChange(of: phase) { _, value in if value == .active { store.sync() } }
                .task(id: phase) {
                    guard phase == .active else { return }
                    while !Task.isCancelled {
                        do { try await Task.sleep(for: .seconds(60)) } catch { return }
                        store.sync()
                    }
                }
                .alert("SportiliApp", isPresented: Binding(get: { store.error != nil }, set: { if !$0 { store.error = nil } })) {
                    Button("OK") { store.error = nil }
                } message: { Text(store.error ?? "") }
        }
        .backgroundTask(.watchConnectivity) { await store.finishConnectivityDelivery() }
    }
    private static var useFixture: Bool {
#if DEBUG
        ProcessInfo.processInfo.arguments.contains("--watch-fixture")
#else
        false
#endif
    }
    @ViewBuilder private var entryView: some View {
#if DEBUG
        if Self.useFixture && (ProcessInfo.processInfo.arguments.contains("--watch-screen=exercise") || ProcessInfo.processInfo.arguments.contains("--watch-screen=sets")) {
            NavigationStack { WatchExerciseView(exercise: WatchFixtures.snapshot.days[0].exercises[0]) }
        } else if Self.useFixture && ProcessInfo.processInfo.arguments.contains("--watch-screen=day") {
            NavigationStack { WatchDayView(day: WatchFixtures.snapshot.days[0]) }
        } else if Self.useFixture && ProcessInfo.processInfo.arguments.contains("--watch-screen=timer") {
            NavigationStack { List { RestStatusView().watchCard(accented: true) }.navigationTitle("Recupero") }
        } else if Self.useFixture && ProcessInfo.processInfo.arguments.contains("--watch-screen=queue") {
            NavigationStack { WatchQueueView() }
        } else if Self.useFixture && ProcessInfo.processInfo.arguments.contains("--watch-screen=crown") {
            WatchCrownFixture()
        } else { WatchHomeView() }
#else
        WatchHomeView()
#endif
    }
}
struct WatchHomeView: View {
    @EnvironmentObject private var store: WatchWorkoutStore
    @State private var linkedDay: WatchDay?
    @State private var missingDay = false
    @State private var confirmReset = false
    var body: some View {
        NavigationStack {
            List {
                Section {
                    if let snapshot = store.state.sync.snapshot, snapshot.binding != nil {
                        ForEach(Array(snapshot.days.enumerated()), id: \.element.id) { index, day in
                            NavigationLink { WatchDayView(day: day) } label: {
                                HStack(spacing: 10) {
                                    WatchNumberBadge(number: index + 1)
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(day.name.lowercased().hasPrefix("giorno") ? day.name : "Giorno " + day.name)
                                            .font(.headline)
                                        Text("\(day.exercises.count) esercizi")
                                            .font(.caption2).foregroundStyle(.secondary)
                                    }
                                    Spacer(minLength: 0)
                                    Image(systemName: "chevron.right").font(.caption2.weight(.semibold)).foregroundStyle(WatchStyle.accent)
                                }.padding(.vertical, 5)
                            }.watchCard(accented: index == 0)
                        }
                        if snapshot.days.isEmpty { emptyWorkout("Nessuna scheda", message: "Apri SportiliApp su iPhone. Se manca anche lì, contatta il trainer.") }
                    } else {
                        emptyWorkout("Scheda non ricevuta", message: "Apri SportiliApp su iPhone, poi tocca Aggiorna scheda qui sul Watch.")
                    }
                } header: { WatchSectionTitle(text: "Scegli il giorno") }
                if store.state.sync.restDeadline != nil {
                    Section { RestStatusView().watchCard(accented: true) }
                }
                Section {
                    NavigationLink { WatchQueueView() } label: {
                        HStack {
                            Label("Pesi registrati", systemImage: "tray.full")
                            Spacer(minLength: 0)
                            let pending = store.state.sync.queue.filter(\.needsSync).count
                            if pending > 0 { Text(pending, format: .number).foregroundStyle(WatchStyle.accent).monospacedDigit() }
                        }.font(.subheadline)
                    }.watchCard()
                    Button { confirmReset = true } label: {
                        Label("Ricomincia allenamento", systemImage: "arrow.counterclockwise").font(.subheadline)
                    }.watchCard()
                } header: { WatchSectionTitle(text: "Allenamento") }
                Section {
                    SyncSummaryView().watchCard()
                    Button { store.sync() } label: {
                        Label("Aggiorna scheda", systemImage: "arrow.triangle.2.circlepath").font(.subheadline)
                    }.watchCard()
                } header: { WatchSectionTitle(text: "Connessione") }
            }.navigationTitle("SportiliApp")
                .confirmationDialog("Ricominciare l’allenamento?", isPresented: $confirmReset) {
                    Button("Ricomincia") { store.newWorkout() }
                    Button("Annulla", role: .cancel) {}
                } message: { Text("Azzera spunte, pesi non registrati e timer. I pesi già registrati restano disponibili.") }
        }
        .onOpenURL { url in
            let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
            let id = items.first { $0.name == "id" }?.value
            let session = items.first { $0.name == "session" }?.value
            if session == WorkoutSurface.current?.session, let day = store.state.sync.snapshot?.days.first(where: { $0.id == id }) { linkedDay = day }
            else { missingDay = true }
        }
        .sheet(item: $linkedDay) { day in NavigationStack { WatchDayView(day: day) } }
        .alert("Giorno non disponibile", isPresented: $missingDay) { Button("Torna alla scheda") {} }

    }
    private func emptyWorkout(_ title: String, message: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: "dumbbell.fill").font(.title2).foregroundStyle(WatchStyle.accent)
            Text(title).font(.headline)
            Text(message).font(.caption).foregroundStyle(.secondary)
        }.padding(.vertical, 5).watchCard(accented: true)
    }
}

struct WatchDayView: View {
    let day: WatchDay
    @EnvironmentObject private var store: WatchWorkoutStore
    var body: some View {
        List {
            Section {
                ForEach(Array(day.exercises.enumerated()), id: \.element.id) { index, exercise in
                    NavigationLink { WatchExerciseView(exercise: exercise) } label: {
                        HStack(alignment: .top, spacing: 10) {
                            Text(index + 1, format: .number.precision(.integerLength(2)))
                                .font(.caption.monospacedDigit()).foregroundStyle(WatchStyle.accent).padding(.top, 2)
                            VStack(alignment: .leading, spacing: 4) {
                                Text(exercise.name).font(.headline)
                                Text(exercise.prescription).font(.caption2).foregroundStyle(.secondary)
                            }
                            Spacer(minLength: 0)
                            if isComplete(exercise) {
                                Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                                    .accessibilityLabel("Serie completate")
                            }
                        }.padding(.vertical, 4)
                    }.watchCard()
                }
            } header: { WatchSectionTitle(text: "\(day.exercises.count) esercizi") }
        }
        .onAppear { WorkoutSurface.save(id: day.id, name: day.name, count: day.exercises.count) }
        .navigationTitle(day.name)
    }
    private func isComplete(_ exercise: WatchExercise) -> Bool {
        let draft = store.draft(for: exercise)
        let count = draft.singleMode ? exercise.repetitions.count : draft.sets.count
        return count > 0 && (0..<count).allSatisfy { store.state.sync.completed[exercise.id]?.contains($0) == true }
    }
}

struct SyncSummaryView: View {
    @EnvironmentObject private var store: WatchWorkoutStore
    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Label(store.reachable ? "iPhone disponibile" : "iPhone non disponibile",
                  systemImage: store.reachable ? "iphone.radiowaves.left.and.right" : "iphone.slash")
                .font(.caption.weight(.medium))
                .foregroundStyle(store.reachable ? Color.green : WatchStyle.accent)
            if let snapshot = store.state.sync.snapshot {
                Text("Scheda ricevuta \(snapshot.generatedAt.formatted(date: .abbreviated, time: .shortened))")
                    .font(.caption2).foregroundStyle(.secondary)
                if let warning = snapshot.warning { Text(warning).font(.caption2).foregroundStyle(WatchStyle.accent) }
                TimelineView(.periodic(from: .now, by: 60)) { context in
                    if context.date.timeIntervalSince(snapshot.generatedAt) > 3600 {
                        Text("La scheda potrebbe essere cambiata. Tocca Aggiorna scheda.").font(.caption2).foregroundStyle(WatchStyle.accent)
                    }
                }
            }
            let pending = store.state.sync.queue.filter(\.needsSync).count
            if pending > 0 { Text("\(pending) da sincronizzare").font(.caption2).foregroundStyle(WatchStyle.accent) }
        }.padding(.vertical, 3)
    }
}

struct WatchQueueView: View {
    @EnvironmentObject private var store: WatchWorkoutStore
    var body: some View {
        List {
            if store.state.sync.queue.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Image(systemName: "tray").font(.title2).foregroundStyle(WatchStyle.accent)
                    Text("Nessun peso registrato").font(.headline)
                    Text("Apri un esercizio e tocca Salva pesi per registrare i kg usati.").font(.caption2).foregroundStyle(.secondary)
                }.padding(.vertical, 5).watchCard()
            }
            ForEach(store.state.sync.queue.reversed()) { item in
                VStack(alignment: .leading, spacing: 7) {
                    HStack {
                        Image(systemName: item.receipt?.status == .saved ? "checkmark.circle.fill" : "clock.arrow.circlepath")
                            .foregroundStyle(item.receipt?.status == .saved ? .green : WatchStyle.accent)
                        Text(Date(timeIntervalSince1970: item.recording.timestamp / 1000), style: .time)
                            .font(.caption2).foregroundStyle(.secondary)
                    }
                    Text(item.recording.exerciseName).font(.headline)
                    if let single = item.recording.single {
                        Text("\(single, specifier: "%g") kg").font(.system(.title3, design: .rounded, weight: .semibold))
                    } else {
                        Text(item.recording.sets.map { "\($0.reps)×\($0.weight.formatted()) kg" }.joined(separator: " · "))
                            .font(.caption.monospacedDigit())
                    }
                    Text(message(item)).font(.caption2)
                        .foregroundStyle(item.receipt?.status == .saved ? .green : WatchStyle.accent)
                }.padding(.vertical, 4).watchCard()
            }
            Button { store.sync() } label: {
                Label("Riprova invio", systemImage: "arrow.triangle.2.circlepath").font(.subheadline)
            }.watchCard()
        }.navigationTitle("Pesi registrati")
    }
    private func message(_ item: WatchQueueItem) -> String {
        WatchRecordingText.message(for: item, activeBinding: store.state.sync.snapshot?.binding)
    }
}

struct RestStatusView: View {
    @EnvironmentObject private var store: WatchWorkoutStore
    var body: some View {
        if let deadline = store.state.sync.restDeadline {
            VStack(spacing: 8) {
                Label("Recupero", systemImage: "timer").font(.caption.weight(.semibold)).foregroundStyle(WatchStyle.accent)
                TimelineView(.periodic(from: .now, by: 1)) { context in
                    VStack(spacing: 8) {
                        if deadline > context.date {
                            Text(deadline, style: .timer)
                                .font(.system(.largeTitle, design: .rounded, weight: .semibold)).monospacedDigit()
                        } else {
                            Label("Recupero terminato", systemImage: "checkmark.circle.fill").foregroundStyle(.green).font(.headline)
                        }
                        Button(deadline > context.date ? "Interrompi" : "Chiudi") { store.stopRest() }
                            .font(.caption).buttonStyle(.borderless)
                    }
                }
            }.frame(maxWidth: .infinity).padding(.vertical, 8)
        }
    }
}
