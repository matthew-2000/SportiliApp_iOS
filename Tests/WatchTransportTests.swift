import Foundation

let transport = CompanionTransport()
let session = WCSession.default
let snapshot = WatchSnapshot(revision: 15, binding: "test-binding", generatedAt: Date(), workoutRevision: "a", days: [], warning: nil)
session.contextError = NSError(domain: "WCErrorDomain", code: 7018)
do { try transport.publish(snapshot); preconditionFailure("Expected context failure") } catch {}
precondition(session.messages.count == 1 && session.messages[0]["kind"] as? String == "snapshot")
print("PASS: rejected application context does not suppress immediate snapshot delivery")

let data = try JSONEncoder().encode(snapshot)
session.reply = ["kind": "snapshot", "payload": data]
var received: WatchSnapshot?
transport.onPacket = { kind, payload in
    if kind == "snapshot" { received = try? JSONDecoder().decode(WatchSnapshot.self, from: payload) }
}
try transport.send(true, kind: "refresh", durable: false)
RunLoop.main.run(until: Date().addingTimeInterval(0.03))
precondition(session.requestedReply && received == snapshot)
print("PASS: Watch refresh requests and consumes a direct snapshot reply")

var fresh = snapshot
transport.onPacket = { kind, _ in if kind == "refresh" { fresh.revision = 16 } }
transport.snapshotForReply = { fresh }
var response: WatchSnapshot?
transport.session(session, didReceiveMessage: ["kind": "refresh", "payload": try JSONEncoder().encode(true)]) { reply in
    if let data = reply["payload"] as? Data { response = try? JSONDecoder().decode(WatchSnapshot.self, from: data) }
}
RunLoop.main.run(until: Date().addingTimeInterval(0.03))
precondition(response?.revision == 16)
print("PASS: reply uses the snapshot after refreshing iPhone state")

transport.snapshotForReply = { nil }
var emptyReply = false
transport.session(session, didReceiveMessage: ["kind": "refresh", "payload": Data()]) { reply in emptyReply = reply.isEmpty }
RunLoop.main.run(until: Date().addingTimeInterval(0.03))
precondition(emptyReply)
print("PASS: no snapshot available still completes the request without a false ACK")
