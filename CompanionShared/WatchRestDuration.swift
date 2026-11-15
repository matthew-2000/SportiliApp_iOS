import Foundation

/// Only complete duration strings are interpreted; trainer prose stays visible for manual choice.
func watchRestSeconds(from source: String) -> Double? {
    let text = source.lowercased().replacingOccurrences(of: " ", with: "")
        .replacingOccurrences(of: "’", with: "'").replacingOccurrences(of: "′", with: "'")
        .replacingOccurrences(of: "″", with: "\"").replacingOccurrences(of: "”", with: "\"")
        .replacingOccurrences(of: ",", with: ".")
    func captures(_ pattern: String) -> [Double?]? {
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)) else { return nil }
        return (1..<match.numberOfRanges).map { index in
            Range(match.range(at: index), in: text).flatMap { Double(text[$0]) }
        }
    }
    var seconds: Double?
    if let parts = captures(#"^([0-9]+):([0-5][0-9])$"#) { seconds = (parts[0] ?? 0) * 60 + (parts[1] ?? 0) }
    else if let parts = captures(#"^([0-9]+)'(?:([0-5]?[0-9])(?:"|'')?)?$"#) { seconds = (parts[0] ?? 0) * 60 + (parts[1] ?? 0) }
    else if let parts = captures(#"^([0-9]+(?:\.[0-9]+)?)(?:minuti|minuto|min|m)(?:([0-9]+)(?:secondi|secondo|sec|s))?$"#) {
        seconds = (parts[0] ?? 0) * 60 + (parts[1] ?? 0)
    } else if let parts = captures(#"^([0-9]+(?:\.[0-9]+)?)(?:secondi|secondo|sec|s|"|'')?$"#) { seconds = parts[0] }
    guard let seconds, seconds.isFinite, seconds > 0 else { return nil }
    return max(5, min(3600, seconds))
}
