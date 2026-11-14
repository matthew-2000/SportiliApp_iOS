func pump() { RunLoop.main.run(until: Date().addingTimeInterval(0.04)) }
let sets = [WorkoutWeightSet(reps: 12, weight: 30), WorkoutWeightSet(reps: 10, weight: 35.5),
            WorkoutWeightSet(reps: 8, weight: 40), WorkoutWeightSet(reps: 6, weight: 45)]
let session = WorkoutWeightSession(id: "session-a", timestamp: 1790000000000, sets: sets)
precondition(WorkoutWeightSession.parse(id: session.id, value: session.firebaseValue) == session)
precondition(Set((session.firebaseValue["sets"] as! [String: Any]).keys) == ["set_00", "set_01", "set_02", "set_03"])
precondition(session.matches(reps: [12, 10, 8, 6]))
precondition(!session.matches(reps: [12, 10, 8]) && !session.matches(reps: [12, 10, 6, 8]))
for (key, value): (String, Any) in [
    ("schemaVersion", 2), ("schemaVersion", true), ("timestamp", 0), ("timestamp", 1790000000000.5),
    ("timestamp", Double.nan), ("sets", [:] as [String: Any]),
    ("sets", ["set_01": ["reps": 12, "weight": 30]]),
    ("sets", ["set_00": ["reps": 12.5, "weight": 30]]),
    ("sets", ["set_00": ["reps": 12, "weight": Double.infinity]]),
    ("sets", ["set_00": ["reps": 12, "weight": 0]])
] {
    var payload = session.firebaseValue; payload[key] = value
    precondition(WorkoutWeightSession.parse(id: "bad", value: payload) == nil, key)
}
precondition(workoutRepetitions(from: "12 - 10 - 8 - 6") == [12, 10, 8, 6])
precondition(workoutRepetitions(from: "4 × 10") == [10, 10, 10, 10])
for text in ["", "3x10 + 3x12", "12-10-8 a cedimento", "3x0", "21x10", "12-999999999999999999999999-8", "4x999999999999999999999999", "12-0-8"] {
    precondition(workoutRepetitions(from: text).isEmpty, text)
}
print("PASS: shared schema round trip, ordering, invalid data, future versions, prescription parsing")

let model = ExerciseDetailViewModel(userCode: "local-test", autoObserve: false,
    initialData: ["lite": UserExerciseData(noteUtente: "keep", weightLogs: ["old": WeightLog(id: "old", timestamp: 1700000000, weight: 20)])])
let path = "users/local-test/weightSessions/lite/session-a"
var succeeded = false
model.saveWeightSession(for: "lite", session: session) { result in if case .success = result { succeeded = true } }
pump()
precondition(succeeded && Database.shared.writes == [path])
precondition(model.weightSessions["lite"] == [session])
precondition(model.data(for: "lite")?.noteUtente == "keep" && model.data(for: "lite")?.weightLogs.count == 1)
var edited = session; edited.sets[0].weight = 32.5
model.saveWeightSession(for: "lite", session: edited) { _ in }; pump()
precondition(Database.shared.writes == [path, path])
precondition(model.weightSessions["lite"] == [edited] && edited.timestamp == session.timestamp)
Database.shared.writeError = NSError(domain: "local", code: 1)
var failed = false
model.saveWeightSession(for: "lite", session: session) { result in if case .failure = result { failed = true } }; pump()
precondition(failed && model.weightSessions["lite"] == [edited])
model.deleteWeightSession(for: "lite", id: session.id) { _ in }; pump()
precondition(model.weightSessions["lite"] == [edited])
Database.shared.writeError = nil
model.deleteWeightSession(for: "lite", id: session.id) { _ in }; pump()
precondition(model.weightSessions["lite"]?.isEmpty == true)
precondition(model.data(for: "lite")?.weightLogs["old"]?.weight == 20)
let before = Database.shared.writes.count
model.saveWeightSession(for: "bad/path", session: session) { _ in }
var invalid = session; invalid.sets[0].weight = .nan
model.saveWeightSession(for: "lite", session: invalid) { _ in }; pump()
precondition(Database.shared.writes.count == before)
print("PASS: isolated writes, idempotent retry, edit preserves timestamp, failure, delete and legacy data unchanged")

let count = Database.shared.listeners.count
var observing: ExerciseDetailViewModel? = ExerciseDetailViewModel(userCode: "reader")
precondition(Database.shared.listeners.count == count + 2)
Database.shared.emit("users/reader/weightSessions", ["lite": [session.id: session.firebaseValue, "bad": ["schemaVersion": 2]]])
pump()
precondition(observing?.weightSessions["lite"] == [session])
Database.shared.emit("users/reader/exerciseData", ["lite": ["noteUtente": "legacy"]]); pump()
precondition(observing?.exerciseKey(from: "Élite") == "lite")
Database.shared.deny("users/reader/weightSessions"); pump()
precondition(observing?.weightSessionsError != nil)
observing?.retryWeightSessions()
precondition(Database.shared.listeners.count == count + 2)
Database.shared.emit("users/reader/weightSessions", [:]); pump()
precondition(observing?.weightSessions.isEmpty == true && observing?.weightSessionsError == nil)
observing = nil
precondition(Database.shared.listeners.count == count)
print("PASS: live read, malformed entry isolation, legacy key resolution, cancellation, retry, listener release")
