// Widget cache boundary for the existing Foundation-only observer harness.
struct WorkoutSurface {
    var dayID: String
    static var current: WorkoutSurface? { nil }
    static func save(id: String, name: String, count: Int) {}
    static func clear() {}
}
