import Foundation

enum PreviewContext {
    static var isPreview: Bool {
        ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
            || ProcessInfo.processInfo.arguments.contains("--local-preview")
    }
}
