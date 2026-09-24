// Minimal SDK boundary doubles. Tests execute the production managers and view model.
typealias DatabaseHandle = UInt
enum DataEventType { case value }
final class DataSnapshot {
    let value: Any?
    let key: String
    var children: [DataSnapshot] {
        (value as? [String: Any] ?? [:]).map { DataSnapshot($0.value, key: $0.key) }
    }
    init(_ value: Any?, key: String = "") { self.value = value; self.key = key }
    func exists() -> Bool { value != nil }
}
final class DatabaseReference {
    let path: String
    var key: String? { path.split(separator: "/").last.map(String.init) }
    init(_ path: String = "") { self.path = path }
    func child(_ name: String) -> DatabaseReference { DatabaseReference(path.isEmpty ? name : path + "/" + name) }
    func observe(_ type: DataEventType, with callback: @escaping (DataSnapshot) -> Void,
                 withCancel cancel: @escaping (Error) -> Void = { _ in }) -> DatabaseHandle {
        Database.shared.next += 1
        let id = Database.shared.next
        Database.shared.listeners[id] = (path, callback, cancel)
        return id
    }
    func removeObserver(withHandle handle: DatabaseHandle) { Database.shared.listeners.removeValue(forKey: handle) }
    func setValue(_ value: Any, withCompletionBlock completion: @escaping (Error?, DatabaseReference) -> Void) {
        write(value, completion: completion)
    }
    func removeValue(completion: ((Error?, DatabaseReference) -> Void)? = nil) {
        write(nil, completion: completion)
    }
    private func write(_ value: Any?, completion: ((Error?, DatabaseReference) -> Void)?) {
        Database.shared.writes.append(path)
        if Database.shared.writeError != nil { completion?(Database.shared.writeError, self); return }
        Database.shared.values[path] = value
        completion?(nil, self)
    }
    func childByAutoId() -> DatabaseReference { child(UUID().uuidString) }
    func observeSingleEvent(of: DataEventType, with callback: (DataSnapshot) -> Void) {
        callback(DataSnapshot(Database.shared.values[path]))
    }
}
final class Database {
    static let shared = Database()
    var next: UInt = 0
    var writes: [String] = []
    var values: [String: Any] = [:]
    var writeError: Error?
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
