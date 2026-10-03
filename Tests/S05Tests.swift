for input in ["47,5", "47.5", " 47,5 "] { precondition(parsedWeightInput(input) == 47.5) }
for input in ["", "0", "-1", "abc", "nan", "inf", "1e309", "1e2", "1,2.3", String(repeating: "9", count: 400)] {
    precondition(parsedWeightInput(input) == nil)
}
print("PASS: decimal separators, whitespace, invalid/non-finite input")
var capturedKey = ""
var capturedWeight = 0.0
var writeCount = 0
var pending: ((Result<WeightLog, ExerciseDataError>) -> Void)?
let localActions = ExerciseDetailActions(addWeight: { key, weight, completion in
    capturedKey = key; capturedWeight = weight; writeCount += 1; pending = completion
}, updateWeight: { key, id, weight, completion in
    capturedKey = key; capturedWeight = weight; writeCount += 1; pending = completion
}, updateNote: { _, _, _ in preconditionFailure("Unexpected note call") })
let handler = WeightActions(localActions)
handler.weightInput = "NaN"; handler.handleWeightConfirm()
precondition(handler.weightError != nil && writeCount == 0)
handler.weightInput = "47,5"; handler.handleWeightConfirm()
precondition(handler.isWeightSaving && capturedKey == "lite" && capturedWeight == 47.5)
handler.handleWeightConfirm(); handler.dismissWeightSheet()
precondition(writeCount == 1 && handler.weightDialogMode == .create)
pending?(.failure(.message("Errore locale")))
precondition(!handler.isWeightSaving && handler.weightInput == "47,5" && handler.weightError == "Errore locale")
handler.handleWeightConfirm()
pending?(.success(WeightLog(id: "new", timestamp: 1790000000000, weight: 47.5)))
precondition(!handler.isWeightSaving && handler.weightDialogMode == .hidden && handler.weightInput.isEmpty)
let record = WeightLog(id: "old", timestamp: 1700000000000, weight: 20)
handler.weightDialogMode = .edit(record); handler.weightInput = "50.25"; handler.handleWeightConfirm()
pending?(.success(WeightLog(id: "old", timestamp: 1790000000000, weight: 50.25)))
precondition(capturedWeight == 50.25 && capturedKey == "lite" && handler.weightDialogMode == .hidden)
print("PASS: real weight handler invalid/pending/duplicate/cancel/failure/retry/edit and legacy key")
let model = ExerciseDetailViewModel(userCode: "test", autoObserve: false, initialData: ["lite": UserExerciseData(noteUtente: "nota")])
let real = WeightActions(ExerciseDetailActions(model: model))
real.weightInput = "25,5"; real.handleWeightConfirm()
RunLoop.main.run(until: Date().addingTimeInterval(0.05))
precondition(Database.shared.writes.count == 1 && Database.shared.writes[0].hasPrefix("users/test/exerciseData/lite/weightLogs/"))
precondition(model.data(for: "lite")?.sortedWeightLogs.last?.weight == 25.5)
precondition(model.data(for: "lite")?.noteUtente == "nota")
print("PASS: existing model writes unchanged per-part payload and preserves note")
for count in [0, 1, 10, 12] {
    let data = (0..<count).map { UniformLog(id: $0, index: $0, date: Date(timeIntervalSince1970: Double($0*$0)), weight: Double($0)) }.reversed()
    let samples = SampleCard(data: Array(data)).samples
    precondition(samples.count == min(count, 10))
    if count == 12 { precondition(samples.first?.weight == 2 && samples.last?.weight == 11) }
}
print("PASS: 0/1/10/>10 samples with irregular dates, latest-ten ordering")

precondition(TimerParsing.parseRiposo("1:30") == 90)
precondition(TimerParsing.parseRiposo("1' 30\"") == 90)
precondition(TimerParsing.parseRiposo("") == 60)
precondition(TimerParsing.parseRiposo("non configurato") == 60)
print("PASS: existing timer durations and 60-second fallback")
