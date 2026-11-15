import Foundation

// Versioned companion protocol; contains no user code, auth credentials or Firebase tokens.
struct WatchSet: Codable, Equatable {
    var reps: Int
    var weight: Double
    var isValid: Bool { (1...1000).contains(reps) && weight.isFinite && weight > 0 }
}
struct WatchExercise: Codable, Equatable, Identifiable {
    var id: String // day/group/exercise occurrence, distinct from the history key
    var key: String
    var name: String
    var prescription: String
    var rest: String
    var repetitions: [Int]
    var lastSingle: Double?
    var lastSets: [WatchSet]
    var reusableSets: [WatchSet]
}
struct WatchDay: Codable, Equatable, Identifiable {
    var id: String
    var name: String
    var exercises: [WatchExercise]
}
struct WatchSnapshot: Codable, Equatable {
    var version = 1
    var revision: Int64
    var binding: String? // random, revocable pairing scope; never the access code
    var generatedAt: Date
    var workoutRevision: String
    var days: [WatchDay]
    var warning: String?
}
struct WatchRecording: Codable, Equatable, Identifiable {
    var id = "watch_" + UUID().uuidString.lowercased()
    var binding: String
    var workoutRevision: String
    var exerciseKey: String
    var exerciseName: String
    var timestamp = (Date().timeIntervalSince1970 * 1000).rounded()
    var single: Double?
    var sets: [WatchSet]
    var isValid: Bool {
        id.hasPrefix("watch_") && UUID(uuidString: String(id.dropFirst(6))) != nil
        && validWatchKey(exerciseKey) && !binding.isEmpty
        && timestamp.isFinite && timestamp > 0 && timestamp <= 253402300799999 && timestamp.rounded() == timestamp
        && ((single?.isFinite == true && single! > 0 && sets.isEmpty)
            || (single == nil && (1...20).contains(sets.count) && sets.allSatisfy(\.isValid)))
    }
    var firebaseValue: [String: Any] {
        if let single { return ["timestamp": timestamp, "weight": single] }
        return ["schemaVersion": 1, "timestamp": timestamp,
                "sets": Dictionary(uniqueKeysWithValues: sets.enumerated().map {
                    (String(format: "set_%02d", $0.offset), ["reps": $0.element.reps, "weight": $0.element.weight] as [String: Any])
                })]
    }
}
func validWatchKey(_ key: String) -> Bool {
    !key.isEmpty && key.rangeOfCharacter(from: CharacterSet(charactersIn: ".#$[]/").union(.controlCharacters)) == nil
}
enum WatchReceiptStatus: String, Codable {
    case delivered, saved, retry, rejected, conflict
    var terminal: Bool { self == .saved || self == .rejected || self == .conflict }
}
struct WatchReceipt: Codable, Equatable {
    var id: String
    var binding: String
    var status: WatchReceiptStatus
    var message: String
}
struct WatchQueueItem: Codable, Equatable, Identifiable {
    var recording: WatchRecording
    var receipt: WatchReceipt?
    var id: String { recording.id }
    var needsSync: Bool { receipt?.status.terminal != true }
}
struct WatchLocalState: Codable {
    var snapshot: WatchSnapshot?
    var queue: [WatchQueueItem] = []
    var completed: [String: Set<Int>] = [:]
    var restDeadline: Date?
    mutating func apply(_ incoming: WatchSnapshot) {
        guard incoming.version == 1, incoming.revision > (snapshot?.revision ?? -1) else { return }
        if snapshot?.binding != incoming.binding || snapshot?.workoutRevision != incoming.workoutRevision {
            completed = [:]
            restDeadline = nil
        }
        snapshot = incoming
    }
    mutating func apply(_ receipt: WatchReceipt) {
        guard let index = queue.firstIndex(where: { $0.id == receipt.id && $0.recording.binding == receipt.binding }) else { return }
        // A delayed delivery ACK must never downgrade a persisted success/conflict.
        guard queue[index].receipt?.status.terminal != true else { return }
        queue[index].receipt = receipt
    }
    var sendable: [WatchQueueItem] {
        queue.filter { $0.needsSync && $0.recording.binding == snapshot?.binding }
    }
}

// Atomic replacement before reporting local success or allowing transport. Corrupt files fail closed.
struct CompanionDisk<Value: Codable> {
    let url: URL
    func load(default fallback: Value) throws -> Value {
        guard FileManager.default.fileExists(atPath: url.path) else { return fallback }
        return try JSONDecoder().decode(Value.self, from: Data(contentsOf: url))
    }
    func save(_ value: Value) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try JSONEncoder().encode(value).write(to: url, options: .atomic)
    }
    static func applicationFile(_ name: String) -> URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("WatchCompanion", isDirectory: true).appendingPathComponent(name)
    }
}
