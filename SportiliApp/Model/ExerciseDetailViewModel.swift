import Foundation
import FirebaseDatabase

enum ExerciseDataError: Error, LocalizedError {
    case message(String)
    var errorDescription: String? {
        switch self {
        case .message(let msg): return msg
        }
    }
}

struct UserExerciseData {
    var noteUtente: String?
    var weightLogs: [String: WeightLog]

    init(noteUtente: String? = nil, weightLogs: [String: WeightLog] = [:]) {
        self.noteUtente = noteUtente
        self.weightLogs = weightLogs
    }

    var hasContent: Bool {
        let hasNote = !(noteUtente?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true)
        return hasNote || !weightLogs.isEmpty
    }

    var sortedWeightLogs: [WeightLog] {
        weightLogs.values.sorted { $0.timestamp < $1.timestamp }
    }
}

final class ExerciseDetailViewModel: ObservableObject {
    @Published private(set) var exerciseData: [String: UserExerciseData] = [:]

    let userCode: String

    private var reference: DatabaseReference?
    private var handle: DatabaseHandle?

    init(userCode: String) {
        self.userCode = userCode
        if !userCode.isEmpty {
            startObservingExerciseData()
        }
    }

    deinit {
        stopObservingExerciseData()
    }

    func exerciseKey(from name: String) -> String {
        Self.makeExerciseKey(from: name)
    }

    static func makeExerciseKey(from name: String) -> String {
        let normalized = name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let sanitized = normalized.replacingOccurrences(of: "[^a-z0-9]+", with: "_", options: .regularExpression)
            .trimmingCharacters(in: CharacterSet(charactersIn: "_"))
        if !sanitized.isEmpty {
            return sanitized
        }
        let fallback = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return "exercise_\(fallback.hashValue)"
    }

    func data(for key: String) -> UserExerciseData? {
        exerciseData[key]
    }

    func addWeightEntry(for key: String, weight: Double, completion: @escaping (Result<WeightLog, ExerciseDataError>) -> Void) {
        guard let exerciseRef = reference(for: key) else {
            DispatchQueue.main.async { completion(.failure(.message("Codice utente non valido"))) }
            return
        }

        guard weight > 0 else {
            DispatchQueue.main.async { completion(.failure(.message("Il peso deve essere maggiore di zero"))) }
            return
        }

        let timestamp = Date().timeIntervalSince1970 * 1000
        let payload: [String: Any] = [
            "weight": weight,
            "timestamp": timestamp
        ]

        let weightLogRef = exerciseRef.child("weightLogs").childByAutoId()
        weightLogRef.setValue(payload) { [weak self] error, _ in
            if let error = error {
                DispatchQueue.main.async { completion(.failure(.message(error.localizedDescription))) }
                return
            }

            let log = WeightLog(id: weightLogRef.key ?? UUID().uuidString, timestamp: timestamp, weight: weight)
            self?.modifyLocalData(for: key) { current in
                var updated = current
                updated.weightLogs[log.id] = log
                return updated
            }

            DispatchQueue.main.async { completion(.success(log)) }
        }
    }

    func updateWeightEntry(for key: String, entryId: String, weight: Double, completion: @escaping (Result<WeightLog, ExerciseDataError>) -> Void) {
        guard let exerciseRef = reference(for: key) else {
            DispatchQueue.main.async { completion(.failure(.message("Codice utente non valido"))) }
            return
        }

        guard weight > 0 else {
            DispatchQueue.main.async { completion(.failure(.message("Il peso deve essere maggiore di zero"))) }
            return
        }

        let timestamp = Date().timeIntervalSince1970 * 1000
        let payload: [String: Any] = [
            "weight": weight,
            "timestamp": timestamp
        ]

        exerciseRef.child("weightLogs").child(entryId).setValue(payload) { [weak self] error, _ in
            if let error = error {
                DispatchQueue.main.async { completion(.failure(.message(error.localizedDescription))) }
                return
            }

            let log = WeightLog(id: entryId, timestamp: timestamp, weight: weight)
            self?.modifyLocalData(for: key) { current in
                var updated = current
                updated.weightLogs[entryId] = log
                return updated
            }

            DispatchQueue.main.async { completion(.success(log)) }
        }
    }

    func deleteWeightEntry(for key: String, entryId: String, completion: @escaping (Result<Void, ExerciseDataError>) -> Void) {
        guard let exerciseRef = reference(for: key) else {
            DispatchQueue.main.async { completion(.failure(.message("Codice utente non valido"))) }
            return
        }

        exerciseRef.child("weightLogs").child(entryId).removeValue { [weak self] error, _ in
            if let error = error {
                DispatchQueue.main.async { completion(.failure(.message(error.localizedDescription))) }
                return
            }

            self?.modifyLocalData(for: key) { current in
                var updated = current
                updated.weightLogs.removeValue(forKey: entryId)
                return updated
            }

            DispatchQueue.main.async { completion(.success(())) }
        }
    }

    func updateUserNote(for key: String, note: String?, completion: @escaping (Result<Void, ExerciseDataError>) -> Void) {
        guard let exerciseRef = reference(for: key) else {
            DispatchQueue.main.async { completion(.failure(.message("Codice utente non valido"))) }
            return
        }

        let trimmedNote = note?.trimmingCharacters(in: .whitespacesAndNewlines)
        let finalNote = trimmedNote?.isEmpty == false ? trimmedNote : nil

        let operation: (@escaping (Error?) -> Void) -> Void = { callback in
            if let finalNote {
                exerciseRef.child("noteUtente").setValue(finalNote) { error, _ in
                    callback(error)
                }
            } else {
                exerciseRef.child("noteUtente").removeValue { error, _ in
                    callback(error)
                }
            }
        }

        operation { [weak self] error in
            if let error = error {
                DispatchQueue.main.async { completion(.failure(.message(error.localizedDescription))) }
                return
            }

            self?.modifyLocalData(for: key) { current in
                var updated = current
                updated.noteUtente = finalNote
                return updated
            }

            DispatchQueue.main.async { completion(.success(())) }
        }
    }

    private func startObservingExerciseData() {
        guard handle == nil else { return }
        let ref = Database.database().reference()
            .child("users")
            .child(userCode)
            .child("exerciseData")
        reference = ref

        handle = ref.observe(.value, with: { [weak self] snapshot in
            guard let self else { return }
            var result: [String: UserExerciseData] = [:]
            for case let child as DataSnapshot in snapshot.children {
                guard let value = child.value as? [String: Any] else { continue }
                let note = value["noteUtente"] as? String
                let weightLogsData = value["weightLogs"] as? [String: Any] ?? [:]
                let parsedLogs = WeightLog.parse(from: weightLogsData)
                let logsDictionary = Dictionary(uniqueKeysWithValues: parsedLogs.map { ($0.id, $0) })
                let data = UserExerciseData(noteUtente: note, weightLogs: logsDictionary)
                if data.hasContent {
                    result[child.key] = data
                }
            }
            DispatchQueue.main.async {
                self.exerciseData = result
            }
        })
    }

    private func stopObservingExerciseData() {
        if let handle, let reference {
            reference.removeObserver(withHandle: handle)
        }
        handle = nil
    }

    private func reference(for key: String) -> DatabaseReference? {
        guard !userCode.isEmpty else { return nil }
        let ref = Database.database().reference()
            .child("users")
            .child(userCode)
            .child("exerciseData")
            .child(key)
        return ref
    }

    private func modifyLocalData(for key: String, transform: @escaping (UserExerciseData) -> UserExerciseData) {
        DispatchQueue.main.async {
            var current = self.exerciseData
            let base = current[key] ?? UserExerciseData()
            let updated = transform(base)
            if updated.hasContent {
                current[key] = updated
            } else {
                current.removeValue(forKey: key)
            }
            self.exerciseData = current
        }
    }
}
