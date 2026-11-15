import Foundation

protocol WCSessionDelegate: AnyObject {}
enum WCSessionActivationState { case notActivated, activated }
struct WCSessionUserInfoTransfer { var userInfo: [String: Any] }
struct WCSessionFile { var metadata: [String: Any]?; var fileURL: URL }
struct WCSessionFileTransfer { var file: WCSessionFile }
final class WCSession {
    static let `default` = WCSession()
    static func isSupported() -> Bool { true }
    weak var delegate: WCSessionDelegate?
    var activationState = WCSessionActivationState.activated
    var isReachable = true
    var hasContentPending = false
    var receivedApplicationContext: [String: Any] = [:]
    var outstandingUserInfoTransfers: [WCSessionUserInfoTransfer] = []
    var messages: [[String: Any]] = []
    var contextError: Error?
    var reply: [String: Any] = [:]
    var requestedReply = false
    func activate() {}
    func transferUserInfo(_ info: [String: Any]) { outstandingUserInfoTransfers.append(.init(userInfo: info)) }
    func sendMessage(_ packet: [String: Any], replyHandler: (([String: Any]) -> Void)?, errorHandler: ((Error) -> Void)?) {
        messages.append(packet)
        requestedReply = replyHandler != nil
        replyHandler?(reply)
    }
    func updateApplicationContext(_ context: [String: Any]) throws { if let contextError { throw contextError } }
    func transferFile(_ url: URL, metadata: [String: Any]?) {}
}
