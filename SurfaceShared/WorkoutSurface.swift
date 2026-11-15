import Foundation
import WidgetKit
#if os(iOS)
import ActivityKit

@available(iOS 16.2, *)
struct RestAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable { var deadline: Date }
}
#endif

struct WorkoutSurface: Codable {
    var dayID: String
    var name: String
    var count: Int
    var session: String
    static let suite = "group.com.matthew.SportiliApp.surfaces"
    static var defaults: UserDefaults { UserDefaults(suiteName: suite)! }
    static var current: WorkoutSurface? {
        guard let data = defaults.data(forKey: "workout") else { return nil }
        return try? JSONDecoder().decode(Self.self, from: data)
    }
    var url: URL {
        var parts = URLComponents()
        parts.scheme = "sportiliapp"; parts.host = "day"
        parts.queryItems = [.init(name: "id", value: dayID), .init(name: "session", value: session)]
        return parts.url!
    }
    static func save(id: String, name: String, count: Int) {
        let value = Self(dayID: id, name: name, count: count, session: defaults.string(forKey: "session") ?? UUID().uuidString)
        defaults.set(value.session, forKey: "session")
        defaults.set(try? JSONEncoder().encode(value), forKey: "workout")
        WidgetCenter.shared.reloadAllTimelines()
    }
    static func clear() {
        defaults.removeObject(forKey: "workout")
        defaults.set(UUID().uuidString, forKey: "session")
        WidgetCenter.shared.reloadAllTimelines()
    }
}
