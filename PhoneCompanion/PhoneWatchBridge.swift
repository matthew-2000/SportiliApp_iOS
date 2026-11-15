import Foundation
import Combine
import CryptoKit
import FirebaseAuth
import FirebaseDatabase

/// Owned by AppDelegate, independent of individual iPhone screens.
final class PhoneWatchBridge {
    static let shared = PhoneWatchBridge()
    private let transport = CompanionTransport()
    private let disk = CompanionDisk<PhoneLedger>(url: CompanionDisk<PhoneLedger>.applicationFile("phone.json"))
    private var ledger = PhoneLedger()
    private var storageHealthy = true
    private var code: String?
    private var model: ExerciseDetailViewModel?
    private var workout: SchedaViewModel?
    private var subscriptions = Set<AnyCancellable>()
    private var authHandle: AuthStateDidChangeListenerHandle?
    private var observers: [NSObjectProtocol] = []
    private var active = Set<String>()
    private var connectedRef: DatabaseReference?
    private var connectedHandle: DatabaseHandle?
    private var connected = false
    private var snapshot: WatchSnapshot?
    private var started = false

    func start() {
        guard !started else { return }; started = true
        do { ledger = try disk.load(default: PhoneLedger()) } catch { storageHealthy = false }
        transport.onPacket = { [weak self] kind, data in self?.receive(kind, data) }
        transport.onReady = { [weak self] in self?.refresh() }
        transport.snapshotForReply = { [weak self] in self?.snapshot }
        transport.onError = { _ in /* Retry on foreground/reachability; avoid immediate error loops. */ }
        authHandle = Auth.auth().addStateDidChangeListener { [weak self] _, _ in self?.refresh() }
        observers.append(NotificationCenter.default.addObserver(forName: UserDefaults.didChangeNotification,
            object: nil, queue: .main) { [weak self] _ in self?.refresh() })
        observers.append(NotificationCenter.default.addObserver(forName: NSNotification.Name("UIApplicationDidBecomeActiveNotification"),
            object: nil, queue: .main) { [weak self] _ in
                self?.workout?.fetchScheda(); self?.model?.retryWeightSessions(); self?.refresh()
            })
        let ref = Database.database().reference(withPath: ".info/connected")
        connectedRef = ref
        connectedHandle = ref.observe(.value) { [weak self] value in
            DispatchQueue.main.async {
                self?.connected = value.value as? Bool == true
                self?.publish(); self?.drain()
            }
        }
        transport.activate()
        refresh()
    }
    private func currentCode() -> String? {
        guard Auth.auth().currentUser != nil, !UserDefaults.standard.bool(forKey: "isAdmin"),
              let value = UserDefaults.standard.string(forKey: "code"), LoginSession.validUserCode(value) else { return nil }
        return value
    }
    private func persist() -> Bool {
        guard storageHealthy else { return false }
        do { try disk.save(ledger); return true } catch { storageHealthy = false; return false }
    }
    private func refresh() {
        guard storageHealthy else { return }
        let nextCode = currentCode()
        let identity = nextCode.flatMap { code in Auth.auth().currentUser.map { $0.uid + ":" + code } }
        if identity != ledger.identity || (nextCode != nil && model == nil) {
            ledger.bind(identity: identity)
            guard persist() else { return }
            code = nextCode
            subscriptions.removeAll(); model = nil; workout = nil; snapshot = nil
            if let nextCode {
                let details = ExerciseDetailViewModel(userCode: nextCode)
                let plan = SchedaViewModel()
                model = details; workout = plan
                details.$exerciseData.combineLatest(details.$weightSessions, details.$weightSessionsError, details.$exerciseDataError)
                    .debounce(for: .milliseconds(200), scheduler: DispatchQueue.main)
                    .sink { [weak self] _ in self?.publish() }.store(in: &subscriptions)
                plan.$scheda.combineLatest(plan.$errorMessage)
                    .debounce(for: .milliseconds(200), scheduler: DispatchQueue.main)
                    .sink { [weak self] _ in self?.publish() }.store(in: &subscriptions)
            }
        }
        publish(); drain()
    }
    private func publish() {
        guard storageHealthy else { return }
        // Check again: Auth/defaults callbacks can arrive in either order.
        guard currentCode() == code else { refresh(); return }
        if ledger.binding != nil, workout?.hasLoadedOnce != true { return }
        if ledger.binding != nil, model?.hasLoadedExerciseData != true || model?.hasLoadedWeightSessions != true { return }
        let days: [WatchDay] = workout?.scheda?.giorni.map { day in
            WatchDay(id: day.id, name: day.name, exercises: day.gruppiMuscolari.flatMap { group in
                group.esercizi.map { exercise in
                    let key = ExerciseDetailViewModel.makeExerciseKey(from: exercise.name)
                    let legacy = model?.exerciseKey(from: exercise.name) ?? key
                    ledger.issuedKeys[key] = legacy
                    let reps = workoutRepetitions(from: exercise.serie)
                    let sessions = model?.weightSessions[key] ?? []
                    let latest = sessions.last
                    let reusable = sessions.last { $0.matches(reps: reps) }
                    let legacyLog = model?.data(for: legacy)?.sortedWeightLogs.last ?? exercise.weightLogs.last
                    return WatchExercise(id: day.id + "/" + group.id + "/" + exercise.id, key: key,
                        name: exercise.name, prescription: exercise.serie, rest: exercise.riposo ?? "",
                        repetitions: reps, lastSingle: legacyLog?.weight,
                        lastSets: latest?.sets.map { WatchSet(reps: $0.reps, weight: $0.weight) } ?? [],
                        reusableSets: reusable?.sets.map { WatchSet(reps: $0.reps, weight: $0.weight) } ?? [])
                }
            })
        } ?? []
        // Revision identifies the prescription, not histories. Updates don't erase an active editor.
        let revisionFields = [String(workout?.scheda?.dataInizio.timeIntervalSince1970 ?? 0),
                              String(workout?.scheda?.durata ?? 0)] + days.flatMap { day in
            [day.id, day.name] + day.exercises.flatMap { [$0.id, $0.key, $0.name, $0.prescription, $0.rest] }
        }
        let revisionData = (try? JSONEncoder().encode(revisionFields)) ?? Data()
        let revision = SHA256.hash(data: revisionData).map { String(format: "%02x", $0) }.joined()
        let warning: String?
        if !connected { warning = "iPhone senza internet. La scheda potrebbe non essere aggiornata." }
        else if workout?.errorMessage != nil || model?.weightSessionsError != nil || model?.exerciseDataError != nil { warning = "Non è stato possibile aggiornare tutti i dati. Riprova da SportiliApp su iPhone." }
        else { warning = nil }
        let value = WatchSnapshot(revision: ledger.nextRevision(), binding: ledger.binding,
            generatedAt: Date(), workoutRevision: revision, days: days, warning: warning)
        guard persist() else { return }
        snapshot = value
        do { try transport.publish(value) } catch {
            // Refresh requests can still return the snapshot directly; log the independent push failure.
            NSLog("Sportili companion: context publication failed (%@)", error.localizedDescription)
        }
    }
    private func receive(_ kind: String, _ data: Data) {
        refresh()
        if kind == "refresh" { return }
        guard kind == "recording", data.count < 32_000,
              let recording = try? JSONDecoder().decode(WatchRecording.self, from: data), storageHealthy else { return }
        let receipt = ledger.receive(recording)
        guard persist() else { return } // Never acknowledge a non-durable inbox.
        try? transport.send(receipt, kind: "receipt")
        drain()
    }
    private func drain() {
        guard storageHealthy, connected, let code, currentCode() == code, let binding = ledger.binding else { return }
        for entry in ledger.inbox.values where !entry.receipt.status.terminal && !active.contains(entry.recording.id) {
            let recording = entry.recording
            guard let path = ledger.path(for: recording, code: code) else { continue }
            active.insert(recording.id)
            // Explicit user path is captured before starting the asynchronous operation.
            WatchFirebaseWriter().save(recording, path: path) { [weak self] result in
                DispatchQueue.main.async {
                    guard let self else { return }
                    self.active.remove(recording.id)
                    guard self.ledger.binding == binding, self.currentCode() == code else { return }
                    let status: WatchReceiptStatus
                    let message: String
                    switch result {
                    case .failure: status = .retry; message = "Pesi non ancora salvati. Controlla la connessione su iPhone e riprova l’invio."
                    case .success(.saved): status = .saved; message = "Salvataggio confermato."
                    default: status = .conflict; message = "Questa registrazione è diversa su iPhone. Controlla lo storico dei pesi."
                    }
                    let receipt = WatchReceipt(id: recording.id, binding: binding, status: status, message: message)
                    self.ledger.inbox[recording.id]?.receipt = receipt
                    guard self.persist() else { return }
                    try? self.transport.send(receipt, kind: "receipt")
                    self.publish()
                }
            }
        }
    }
}
