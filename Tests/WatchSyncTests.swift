import Foundation

func check(_ condition: @autoclosure () -> Bool, _ name: String) {
    precondition(condition(), name)
}
var phone = PhoneLedger()
phone.bind(identity: "uid:old-code")
let oldBinding = phone.binding!
phone.issuedKeys["panca"] = "legacy_panca"
var recording = WatchRecording(binding: oldBinding, workoutRevision: "plan-a", exerciseKey: "panca", exerciseName: "Panca",
    single: nil, sets: [WatchSet(reps: 12, weight: 30), WatchSet(reps: 10, weight: 35), WatchSet(reps: 8, weight: 40), WatchSet(reps: 6, weight: 45)])
check(recording.isValid, "pyramid")
check(phone.path(for: recording, code: "old-code") == "users/old-code/weightSessions/panca/\(recording.id)", "session path")
let delivered = phone.receive(recording)
check(delivered.status == .delivered, "delivery is not persistence")
check(phone.receive(recording) == delivered && phone.inbox.count == 1, "delivery dedup")
var edited = recording; edited.sets[0].weight = 32
check(phone.receive(edited).status == .conflict && phone.inbox[recording.id]?.recording == recording, "immutable ID")
check(watchInsertDecision(existing: nil, recording: recording) == .insert, "first insert")
check(watchInsertDecision(existing: recording.firebaseValue, recording: recording) == .identical, "server duplicate")
check(watchInsertDecision(existing: edited.firebaseValue, recording: recording) == .conflict, "concurrent edit preserved")
check(watchInsertDecision(existing: ["future": true], recording: recording) == .conflict, "unknown data preserved")
print("PASS: paths, pyramid wire contract, UUID retry, delivery ACK, concurrent edits")

let snapshot = WatchSnapshot(revision: 10, binding: oldBinding, generatedAt: Date(), workoutRevision: "plan-a", days: [], warning: nil)
var watch = WatchLocalState(); watch.apply(snapshot)
watch.queue.append(WatchQueueItem(recording: recording))
watch.completed["occurrence"] = [0, 2]
watch.restDeadline = Date().addingTimeInterval(90)
let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
defer { try? FileManager.default.removeItem(at: directory) }
let watchDisk = CompanionDisk<WatchLocalState>(url: directory.appendingPathComponent("watch.json"))
let phoneDisk = CompanionDisk<PhoneLedger>(url: directory.appendingPathComponent("phone.json"))
try watchDisk.save(watch); try phoneDisk.save(phone)
watch = try watchDisk.load(default: WatchLocalState())
phone = try phoneDisk.load(default: PhoneLedger())
check(watch.sendable.count == 1 && watch.completed["occurrence"] == [0, 2] && watch.restDeadline != nil, "offline restart")
check(phone.receive(recording) == delivered, "phone restart retry")
watch.apply(delivered)
check(watch.sendable.count == 1, "delivery keeps queue")
let retry = WatchReceipt(id: recording.id, binding: oldBinding, status: .retry, message: "denied")
watch.apply(retry); check(watch.sendable.count == 1, "error retry")
let saved = WatchReceipt(id: recording.id, binding: oldBinding, status: .saved, message: "Firebase committed")
phone.inbox[recording.id]?.receipt = saved; try phoneDisk.save(phone)
watch.apply(saved); watch.apply(delivered); watch.apply(retry)
check(watch.queue[0].receipt == saved && watch.sendable.isEmpty, "out of order ACKs")
phone = try phoneDisk.load(default: PhoneLedger())
check(phone.receive(recording) == saved, "lost ACK redelivered after restart without rewrite")
print("PASS: durable offline queues, retry, out-of-order receipts, restart after commit")

watch.queue.append(WatchQueueItem(recording: WatchRecording(binding: oldBinding, workoutRevision: "plan-a", exerciseKey: "panca", exerciseName: "Panca", single: 35, sets: [])))
var next = snapshot; next.revision = 11; next.workoutRevision = "plan-b"; watch.apply(next)
check(watch.completed.isEmpty && watch.restDeadline == nil && watch.sendable.count == 1, "updated plan keeps historical queue")
check(watch.sendable[0].recording.workoutRevision == "plan-a", "original prescription retained")
watch.apply(snapshot); check(watch.snapshot?.workoutRevision == "plan-b", "stale context ignored")
phone.bind(identity: nil)
check(phone.receive(recording).status == .rejected && phone.path(for: recording, code: "new-code") == nil, "logout")
phone.bind(identity: "uid:new-code")
check(phone.binding != oldBinding, "rotated binding")
phone.issuedKeys["panca"] = "panca"
check(phone.receive(recording).status == .rejected && phone.inbox.isEmpty, "old queue never enters new account")
next.revision = 12; next.binding = phone.binding; watch.apply(next)
check(watch.sendable.isEmpty && watch.queue.count == 2, "watch quarantine preserves old recording")
phone.bind(identity: "uid:old-code")
check(phone.binding != oldBinding && phone.receive(recording).status == .rejected, "relogin cannot resurrect revoked binding")
var single = recording; single.single = 30; single.sets = []; single.binding = phone.binding!
phone.issuedKeys["panca"] = "legacy_panca"
check(single.isValid && phone.path(for: single, code: "old-code") == "users/old-code/exerciseData/legacy_panca/weightLogs/\(single.id)", "legacy alias single")
check(single.firebaseValue["sets"] == nil && single.firebaseValue["schemaVersion"] == nil, "legacy has no invented reps")
var bad = recording; bad.sets[0].weight = .nan; check(!bad.isValid, "nan")
bad = recording; bad.id = "../../user"; check(!bad.isValid, "path injection")
try Data("corrupt".utf8).write(to: watchDisk.url)
do { _ = try watchDisk.load(default: WatchLocalState()); preconditionFailure("corruption silently erased") } catch {}
print("PASS: plan changes, stale snapshots, logout, user switch, relogin, legacy isolation, invalid data, corrupt storage")
for (source, expected) in [("90", 90.0), ("90 secondi", 90), ("1 minuto", 60), ("1:30", 90),
                           ("1'30\"", 90), ("1’30″", 90), ("2m 30s", 150), ("30''", 30), ("1,5 min", 90)] {
    check(watchRestSeconds(from: source) == expected, "duration \(source)")
}
for source in ["", "nan", "inf", "-30", "0", "1:90", "30-60 sec", "recupera 90 secondi", "3x10"] {
    check(watchRestSeconds(from: source) == nil, "ambiguous duration \(source)")
}
print("PASS: recovery durations, minute/second/quote formats, ambiguity and non-finite values")
// Resolve a newly-created legacy alias when accepting a single, then pin its retry path.
_ = phone.receive(single)
let pinnedPath = phone.path(for: single, code: "old-code")
phone.issuedKeys["panca"] = "new_alias"
check(phone.path(for: single, code: "old-code") == pinnedPath, "alias change cannot redirect an accepted retry")
print("PASS: legacy write path pinned across alias changes and retries")
