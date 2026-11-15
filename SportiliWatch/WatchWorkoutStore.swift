import SwiftUI
import UserNotifications
import WatchKit

struct WatchDraft: Codable, Equatable {
    var singleMode = false
    var single = 20.0
    var sets: [WatchSet]
}
struct WatchAppState: Codable {
    var sync = WatchLocalState()
    var drafts: [String: WatchDraft] = [:]
}
final class WatchWorkoutStore: NSObject, ObservableObject, UNUserNotificationCenterDelegate {
    @Published private(set) var state = WatchAppState()
    @Published var error: String?
    @Published var reachable = false
    private let disk: CompanionDisk<WatchAppState>
    private let transport = CompanionTransport()
    private var healthy = true
    private let fixture: Bool
    private let restID = "sportili-rest"
    init(fixture: Bool = false) {
        self.fixture = fixture
        disk = CompanionDisk(url: CompanionDisk<WatchAppState>.applicationFile("watch.json"))
        super.init()
        if fixture {
            state.sync.snapshot = WatchFixtures.snapshot
#if DEBUG
            if ProcessInfo.processInfo.arguments.contains("--watch-screen=timer") {
                state.sync.restDeadline = Date().addingTimeInterval(90)
            }
#endif
        } else {
            do { state = try disk.load(default: WatchAppState()) }
            catch { healthy = false; self.error = "Impossibile leggere i pesi salvati sul Watch. Chiudi e riapri l’app. Se il problema continua, non disinstallarla: potresti perdere i pesi non ancora inviati." }
        }
        UNUserNotificationCenter.current().delegate = self
        transport.onPacket = { [weak self] kind, data in self?.receive(kind, data) }
        transport.onReady = { [weak self] in self?.sync() }
        transport.onError = { [weak self] _ in
            self?.reachable = false // Disconnection is a visible status, not an interrupting workout alert.
        }
        if !fixture { transport.activate() }
#if DEBUG
        if fixture && ProcessInfo.processInfo.arguments.contains("--watch-self-check") {
            let exercise = WatchFixtures.snapshot.days[0].exercises[0]
            var draft = self.draft(for: exercise)
            draft.sets = exercise.reusableSets
            edit(exercise, draft)
            toggleCompleted(exercise, index: 0)
            precondition(state.sync.completed[exercise.id] == [0])
            precondition(save(exercise) && state.sync.queue.count == 1)
            precondition(state.sync.queue[0].recording.sets.map(\.reps) == [12, 10, 8, 6])
            newWorkout()
            precondition(state.sync.queue.count == 1 && state.sync.completed.isEmpty)
            let result = ProcessInfo.processInfo.environment["WATCH_TEST_RESULT"] ?? "/tmp/watch-self-check.txt"
            try? "PASS".write(toFile: result, atomically: true, encoding: .utf8)
        }
#endif
    }
    @discardableResult
    private func update(_ change: (inout WatchAppState) -> Void) -> Bool {
        guard healthy else { return false }
        var next = state; change(&next)
        do {
            if !fixture { try disk.save(next) }
            state = next
            return true
        } catch { self.error = "Modifica non salvata. Controlla lo spazio libero sul Watch e riprova."; return false }
    }
    func draft(for exercise: WatchExercise) -> WatchDraft {
        state.drafts[exercise.id] ?? WatchDraft(singleMode: exercise.repetitions.isEmpty,
            single: exercise.lastSingle ?? 20,
            sets: exercise.repetitions.map { WatchSet(reps: $0, weight: 20) })
    }
    func edit(_ exercise: WatchExercise, _ draft: WatchDraft) {
        update { $0.drafts[exercise.id] = draft }
    }
    func save(_ exercise: WatchExercise) -> Bool {
        guard let snapshot = state.sync.snapshot, let binding = snapshot.binding,
              snapshot.days.flatMap(\.exercises).contains(where: { $0.id == exercise.id && $0.key == exercise.key }) else {
            error = "La scheda è cambiata. Torna all’elenco dei giorni e riapri l’esercizio."; return false
        }
        let draft = draft(for: exercise)
        let recording = WatchRecording(binding: binding, workoutRevision: snapshot.workoutRevision,
            exerciseKey: exercise.key, exerciseName: exercise.name,
            single: draft.singleMode ? draft.single : nil, sets: draft.singleMode ? [] : draft.sets)
        guard recording.isValid else { error = "Inserisci pesi maggiori di zero e ripetizioni valide."; return false }
        guard update({ $0.sync.queue.append(WatchQueueItem(recording: recording)) }) else { return false }
        WKInterfaceDevice.current().play(.success)
        sync()
        return true
    }
    func toggleCompleted(_ exercise: WatchExercise, index: Int) {
        update {
            var done = $0.sync.completed[exercise.id] ?? []
            if !done.insert(index).inserted { done.remove(index) }
            $0.sync.completed[exercise.id] = done
        }
    }
    func newWorkout() {
        if update({ $0.sync.completed = [:]; $0.drafts = [:]; $0.sync.restDeadline = nil }) { cancelNotification() }
    }
    func sync() {
        reachable = transport.reachable
        guard !fixture else { return }
        do {
            try transport.send(true, kind: "refresh", durable: false)
            for item in state.sync.sendable { try transport.send(item.recording, kind: "recording") }
        } catch { self.error = "Invio non riuscito. I pesi restano sul Watch. Riprova da Pesi registrati." }
    }
    @MainActor func finishConnectivityDelivery() async {
        guard !fixture else { return }
        // Keep the refresh task open while WC hands off its queued content to our delegate.
        for _ in 0..<200 {
            if !transport.hasPendingContent { break }
            try? await Task.sleep(for: .milliseconds(100))
        }
        await Task.yield()
    }
    private func receive(_ kind: String, _ data: Data) {
        if kind == "snapshot", let snapshot = try? JSONDecoder().decode(WatchSnapshot.self, from: data) {
            let previous = state.sync.snapshot
            if update({
                $0.sync.apply(snapshot)
                if previous?.binding != $0.sync.snapshot?.binding || previous?.workoutRevision != $0.sync.snapshot?.workoutRevision {
                    $0.drafts = [:]
                }
            }) {
                if state.sync.restDeadline == nil { cancelNotification() }
                if let previous, previous.binding == snapshot.binding,
                   previous.workoutRevision != snapshot.workoutRevision,
                   state.sync.snapshot?.revision == snapshot.revision {
                    error = "È arrivata una nuova scheda. Spunte, pesi non registrati e timer sono stati azzerati. I pesi già registrati restano disponibili."
                }
                // Context receipt does not trigger retries; a server error must not create a retry loop.
            }
        } else if kind == "receipt", let receipt = try? JSONDecoder().decode(WatchReceipt.self, from: data) {
            update { $0.sync.apply(receipt) }
        }
    }
    func startRest(seconds: Double) {
        let duration = max(5, min(3600, seconds))
        let deadline = Date().addingTimeInterval(duration)
        guard update({ $0.sync.restDeadline = deadline }) else { return }
        cancelNotification()
        let center = UNUserNotificationCenter.current()
        center.requestAuthorization(options: [.alert, .sound]) { [weak self] allowed, authError in
            DispatchQueue.main.async {
                guard let self, self.state.sync.restDeadline == deadline else { return }
                guard allowed, authError == nil else {
                    self.error = "Non riceverai l’avviso di fine recupero. Per abilitarlo, consenti le notifiche di SportiliApp nelle impostazioni del Watch."
                    return
                }
                let content = UNMutableNotificationContent()
                content.title = "Recupero terminato"
                content.body = "Puoi iniziare la prossima serie."
                content.sound = .default
                let remaining = max(1, deadline.timeIntervalSinceNow)
                center.add(UNNotificationRequest(identifier: self.restID, content: content,
                    trigger: UNTimeIntervalNotificationTrigger(timeInterval: remaining, repeats: false))) { error in
                        DispatchQueue.main.async {
                            if self.state.sync.restDeadline == nil { self.cancelNotification() }
                            else if error != nil, self.state.sync.restDeadline == deadline {
                                self.error = "Avviso di fine recupero non impostato. Controlla il timer sullo schermo."
                            }
                        }
                    }
            }
        }
    }
    func stopRest() { if update({ $0.sync.restDeadline = nil }) { cancelNotification() } }
    private func cancelNotification() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [restID])
        UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: [restID])
    }
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        WKInterfaceDevice.current().play(.notification)
        completionHandler([.banner, .sound])
    }
}

enum WatchFixtures {
    static let snapshot = WatchSnapshot(revision: 1, binding: "fixture-binding", generatedAt: Date().addingTimeInterval(-7200),
        workoutRevision: "fixture-plan", days: [WatchDay(id: "giorno1", name: "Giorno A", exercises: [
            WatchExercise(id: "a/panca", key: "panca", name: "Panca piana", prescription: "12-10-8-6", rest: "90 secondi",
                repetitions: [12, 10, 8, 6], lastSingle: 30,
                lastSets: [WatchSet(reps: 12, weight: 30), WatchSet(reps: 10, weight: 35), WatchSet(reps: 8, weight: 40), WatchSet(reps: 6, weight: 45)],
                reusableSets: [WatchSet(reps: 12, weight: 30), WatchSet(reps: 10, weight: 35), WatchSet(reps: 8, weight: 40), WatchSet(reps: 6, weight: 45)]),
            WatchExercise(id: "a/curl", key: "curl", name: "Curl manubri", prescription: "3x10", rest: "1 minuto",
                repetitions: [10, 10, 10], lastSingle: 12, lastSets: [], reusableSets: [])])], warning: "Anteprima locale • dati non aggiornati")
}
