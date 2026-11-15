import Foundation
import WatchConnectivity
import OSLog

// All app state is confined to the main queue. WCSession delegate callbacks aren't.
final class CompanionTransport: NSObject, WCSessionDelegate {
    var onPacket: ((String, Data) -> Void)?
    var onReady: (() -> Void)?
    var onError: ((String) -> Void)?
    var snapshotForReply: (() -> WatchSnapshot?)?
    private let logger = Logger(subsystem: "com.matthew.SportiliApp.companion", category: "transport")
    private var session: WCSession? { WCSession.isSupported() ? WCSession.default : nil }
    var reachable: Bool { session?.isReachable == true }
    var hasPendingContent: Bool { session?.hasContentPending == true || session?.activationState != .activated }
    func activate() { session?.delegate = self; session?.activate() }
    func send<T: Encodable>(_ value: T, kind: String, durable: Bool = true) throws {
        let data = try JSONEncoder().encode(value)
        guard let session, session.activationState == .activated else { return }
        let packet: [String: Any] = ["kind": kind, "payload": data]
        if durable {
            // A queued WC transfer isn't an acknowledgement of Firebase persistence.
            let alreadyQueued = session.outstandingUserInfoTransfers.contains {
                $0.userInfo["kind"] as? String == kind && $0.userInfo["payload"] as? Data == data
            }
            if !alreadyQueued { session.transferUserInfo(packet) }
        }
        if session.isReachable { session.sendMessage(packet, replyHandler: kind == "refresh" ? { [weak self] reply in
            self?.receive(reply)
        } : nil) { [weak self] error in
            self?.logger.error("Immediate delivery failed: \(error.localizedDescription, privacy: .public)")
            DispatchQueue.main.async { self?.onError?(error.localizedDescription) }
        } }
    }
    func publish(_ snapshot: WatchSnapshot) throws {
        guard let session, session.activationState == .activated else { return }
        let data = try JSONEncoder().encode(snapshot)
        // Independent delivery paths: a rejected application context must not skip the live message.
        if session.isReachable, data.count < 55_000 { try send(snapshot, kind: "snapshot", durable: false) }
        if data.count < 55_000 {
            try session.updateApplicationContext(["kind": "snapshot", "payload": data])
        } else {
            // Large workouts use WC's file transport instead of exceeding the context limit.
            let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".json")
            try data.write(to: url, options: .atomic)
            session.transferFile(url, metadata: ["kind": "snapshot"])
        }
    }
    private func receive(_ packet: [String: Any]) {
        guard let kind = packet["kind"] as? String, let data = packet["payload"] as? Data else { return }
        DispatchQueue.main.async { [weak self] in self?.onPacket?(kind, data) }
    }
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        DispatchQueue.main.async { [weak self] in
            if let error { self?.onError?(error.localizedDescription) }
            if activationState == .activated {
                self?.receive(session.receivedApplicationContext)
                self?.onReady?()
            }
        }
    }
    func sessionReachabilityDidChange(_ session: WCSession) {
        DispatchQueue.main.async { [weak self] in self?.onReady?() }
    }
    func session(_ session: WCSession, didReceiveMessage message: [String: Any]) { receive(message) }
    func session(_ session: WCSession, didReceiveMessage message: [String: Any],
                 replyHandler: @escaping ([String: Any]) -> Void) {
        DispatchQueue.main.async { [weak self] in
            guard let self, let kind = message["kind"] as? String, let data = message["payload"] as? Data else {
                replyHandler([:]); return
            }
            self.onPacket?(kind, data)
            // A Watch-initiated request can receive its response even when iPhone's
            // installed/reachable metadata hasn't caught up with the paired Watch yet.
            guard kind == "refresh", let snapshot = self.snapshotForReply?(),
                  let payload = try? JSONEncoder().encode(snapshot), payload.count < 55_000 else {
                replyHandler([:]); return
            }
            replyHandler(["kind": "snapshot", "payload": payload])
        }
    }
    func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any] = [:]) { receive(userInfo) }
    func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) { receive(applicationContext) }
    func session(_ session: WCSession, didReceive file: WCSessionFile) {
        guard file.metadata?["kind"] as? String == "snapshot", let data = try? Data(contentsOf: file.fileURL) else { return }
        receive(["kind": "snapshot", "payload": data])
    }
    func session(_ session: WCSession, didFinish fileTransfer: WCSessionFileTransfer, error: Error?) {
        try? FileManager.default.removeItem(at: fileTransfer.file.fileURL)
        if let error { DispatchQueue.main.async { [weak self] in self?.onError?(error.localizedDescription) } }
    }
#if os(iOS)
    func sessionDidBecomeInactive(_ session: WCSession) {}
    func sessionDidDeactivate(_ session: WCSession) { session.activate() }
    func sessionWatchStateDidChange(_ session: WCSession) {
        DispatchQueue.main.async { [weak self] in self?.onReady?() }
    }
#endif
}
