import Foundation

struct PhoneInboxEntry: Codable {
    var recording: WatchRecording
    var receipt: WatchReceipt
    var legacyKey: String?
}
struct PhoneLedger: Codable {
    // Private to iPhone. Only binding and revision appear in the wire protocol.
    var identity: String?
    var binding: String?
    var revision: Int64 = 0
    var issuedKeys: [String: String] = [:] // canonical -> existing legacy alias
    var inbox: [String: PhoneInboxEntry] = [:]
    mutating func bind(identity next: String?) {
        guard identity != next else { return }
        identity = next
        binding = next == nil ? nil : UUID().uuidString
        issuedKeys = [:]
        // Retain only the current account's receipts. Revoked bindings are never accepted again.
        inbox = [:]
    }
    mutating func nextRevision() -> Int64 {
        revision = max(revision + 1, Int64(Date().timeIntervalSince1970 * 1_000_000))
        return revision
    }
    mutating func receive(_ recording: WatchRecording) -> WatchReceipt {
        func receipt(_ status: WatchReceiptStatus, _ message: String) -> WatchReceipt {
            WatchReceipt(id: recording.id, binding: recording.binding, status: status, message: message)
        }
        guard recording.isValid, recording.binding == binding, identity != nil,
              issuedKeys[recording.exerciseKey] != nil else {
            return receipt(.rejected, "Accesso su iPhone cambiato. Questi pesi restano sul Watch.")
        }
        if let existing = inbox[recording.id] {
            guard existing.recording == recording else { return receipt(.conflict, "Questa registrazione contiene dati diversi. Controlla lo storico dei pesi su iPhone.") }
            return existing.receipt
        }
        let delivered = receipt(.delivered, "Ricevuto dall’iPhone. Salvataggio non ancora confermato.")
        inbox[recording.id] = PhoneInboxEntry(recording: recording, receipt: delivered,
            legacyKey: issuedKeys[recording.exerciseKey])
        return delivered
    }
    func path(for recording: WatchRecording, code: String) -> String? {
        guard recording.binding == binding, recording.isValid, validWatchKey(code),
              let legacy = inbox[recording.id]?.legacyKey ?? issuedKeys[recording.exerciseKey], validWatchKey(legacy) else { return nil }
        if recording.single != nil {
            return "users/\(code)/exerciseData/\(legacy)/weightLogs/\(recording.id)"
        }
        return "users/\(code)/weightSessions/\(recording.exerciseKey)/\(recording.id)"
    }
}

// Pure decision used by the Firebase transaction, tested independently and against the emulator.
enum WatchInsertDecision { case insert, identical, conflict }
func watchInsertDecision(existing: Any?, recording: WatchRecording) -> WatchInsertDecision {
    guard let existing, !(existing is NSNull) else { return .insert }
    guard let dictionary = existing as? NSDictionary else { return .conflict }
    return dictionary.isEqual(to: recording.firebaseValue) ? .identical : .conflict
}
