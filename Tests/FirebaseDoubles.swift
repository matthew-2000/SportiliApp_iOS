// Minimal SDK boundary doubles. Tests execute the production managers and view model.
typealias DatabaseHandle = UInt
enum DataEventType { case value }
final class DataSnapshot {
    let value: Any?
    init(_ value: Any?) { self.value = value }
    func exists() -> Bool { value != nil }
}
final class DatabaseReference {
    let path: String
    init(_ path: String = "") { self.path = path }
    func child(_ name: String) -> DatabaseReference { DatabaseReference(path.isEmpty ? name : path + "/" + name) }
    func observe(_ type: DataEventType, with callback: @escaping (DataSnapshot) -> Void,
                 withCancel cancel: @escaping (Error) -> Void) -> DatabaseHandle {
        Database.shared.next += 1
        let id = Database.shared.next
        Database.shared.listeners[id] = (path, callback, cancel)
        return id
    }
    func removeObserver(withHandle handle: DatabaseHandle) { Database.shared.listeners.removeValue(forKey: handle) }
    func setValue(_ value: Any, withCompletionBlock completion: (Error?, DatabaseReference) -> Void) { completion(nil, self) }
}
final class Database {
    static let shared = Database()
    var next: UInt = 0
    var listeners: [UInt: (String, (DataSnapshot) -> Void, (Error) -> Void)] = [:]
    static func database() -> Database { shared }
    func reference() -> DatabaseReference { DatabaseReference() }
    func emit(_ path: String, _ value: Any?) {
        for item in Array(listeners.values) where item.0 == path { item.1(DataSnapshot(value)) }
    }
    func deny(_ path: String) {
        for item in Array(listeners.values) where item.0 == path { item.2(NSError(domain: "test", code: 1)) }
    }
}
final class ProfileChange {
    var displayName: String?
    func commitChanges(completion: ((Error?) -> Void)?) { completion?(nil) }
}
final class FakeUser { func createProfileChangeRequest() -> ProfileChange { ProfileChange() } }
struct AuthResult { var user = FakeUser() }
final class Auth {
    static let shared = Auth()
    var currentUser: FakeUser? = FakeUser()
    var error: Error?
    static func auth() -> Auth { shared }
    func signInAnonymously(completion: (AuthResult?, Error?) -> Void) { completion(AuthResult(), error) }
}
