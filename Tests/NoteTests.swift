let db = Database.shared
let weight = WeightLog(id: "log", timestamp: 1790000000000, weight: 40)
let model = ExerciseDetailViewModel(userCode: "test", autoObserve: false, initialData: [
    "panca": UserExerciseData(noteUtente: "prima", weightLogs: ["log": weight]),
    "croci": UserExerciseData(noteUtente: "altra parte")
])
let actions = NoteActions(model)
let notePath = "users/test/exerciseData/panca/noteUtente"
let legacyPath = "users/test/scheda/giorni/giorno1/gruppiMuscolari/gruppo1/esercizi/esercizio1/noteUtente"
let historyPath = "users/test/exerciseData/panca/weightLogs/log"
db.values[legacyPath] = "copia legacy"
db.values[historyPath] = weight.firebaseValue
func drain() { RunLoop.main.run(until: Date().addingTimeInterval(0.02)) }
var result: Bool?
actions.noteInput = "  nuova nota  "
actions.saveNote(for: "panca") { result = $0 }
drain()
precondition(result == true && actions.lastSyncedNote == "nuova nota")
precondition(db.writes == [notePath], "Exactly one write, to the authoritative per-part note")
precondition(model.data(for: "panca")?.noteUtente == "nuova nota")
precondition(model.data(for: "croci")?.noteUtente == "altra parte")
precondition(model.data(for: "panca")?.weightLogs["log"] == weight)
precondition(db.values[legacyPath] as? String == "copia legacy")
precondition(db.values[historyPath] != nil)

db.writeError = NSError(domain: "denied", code: 1)
actions.noteInput = "da riprovare"
actions.saveNote(for: "panca") { result = $0 }
drain()
precondition(result == false && actions.error != nil)
precondition(model.data(for: "panca")?.noteUtente == "nuova nota")
precondition(actions.noteInput == "da riprovare")
db.writeError = nil
actions.saveNote(for: "panca") { result = $0 }
drain()
precondition(result == true && model.data(for: "panca")?.noteUtente == "da riprovare")

actions.removeNote(for: "panca") { result = $0 }
drain()
precondition(result == true && db.values[notePath] == nil)
precondition(model.data(for: "panca")?.weightLogs["log"] == weight)
precondition(model.data(for: "croci")?.noteUtente == "altra parte")
actions.noteInput = "  "
actions.saveNote(for: "croci") { result = $0 }
drain()
precondition(result == true && model.data(for: "croci")?.noteUtente == nil)
precondition(db.writes.allSatisfy { $0.contains("/exerciseData/") && $0.hasSuffix("/noteUtente") })
print("PASS: authoritative per-part notes, one write, error/retry, deletion, preserved history and legacy data")

precondition(ExerciseDetailViewModel.makeExerciseKey(from: " Panca inclinata ") == "panca_inclinata")
precondition(ExerciseDetailViewModel.makeExerciseKey(from: "Élite") == "elite")
precondition(ExerciseDetailViewModel.makeExerciseKey(from: "🏋️") == "exercise_u_0a932e41848fbb46")
let legacyModel = ExerciseDetailViewModel(userCode: "test", autoObserve: false, initialData: [
    "lite": UserExerciseData(noteUtente: "storica")
])
precondition(legacyModel.exerciseKey(from: "Élite") == "lite")
print("PASS: stable cross-platform exercise keys and legacy-key reuse")
