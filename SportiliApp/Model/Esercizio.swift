//
//  Esercizio.swift
//  SportiliApp
//
//  Created by Matteo Ercolino on 03/06/24.
//

import Foundation
import CoreFoundation

// Shared wire format: users/{code}/weightSessions/{exerciseKey}/{sessionId}.
// Keep outside exerciseData: installed iOS releases can delete that subtree.
struct WorkoutWeightSet: Equatable {
    var reps: Int
    var weight: Double
    var isValid: Bool { (1...1000).contains(reps) && weight.isFinite && weight > 0 }
}

struct WorkoutWeightSession: Identifiable, Equatable {
    var id: String
    var timestamp: Double
    var sets: [WorkoutWeightSet]
    var date: Date { Date(timeIntervalSince1970: timestamp / 1000) }
    var isValid: Bool {
        timestamp.isFinite && timestamp > 0 && timestamp <= 253402300799999 && timestamp.rounded() == timestamp
            && (1...20).contains(sets.count) && sets.allSatisfy(\.isValid)
    }
    var firebaseValue: [String: Any] {
        ["schemaVersion": 1, "timestamp": timestamp,
         "sets": Dictionary(uniqueKeysWithValues: sets.enumerated().map { index, set in
             (String(format: "set_%02d", index), ["reps": set.reps, "weight": set.weight] as [String: Any])
         })]
    }
    static func parse(id: String, value: Any?) -> WorkoutWeightSession? {
        guard let data = value as? [String: Any],
              let version = sessionNumber(data["schemaVersion"]), version.doubleValue == 1,
              let timestamp = sessionNumber(data["timestamp"]),
              let rawSets = data["sets"] as? [String: Any], (1...20).contains(rawSets.count) else { return nil }
        var sets: [WorkoutWeightSet] = []
        for index in 0..<rawSets.count {
            guard let set = rawSets[String(format: "set_%02d", index)] as? [String: Any],
                  let reps = sessionNumber(set["reps"]), (1...1000).contains(reps.doubleValue),
                  reps.doubleValue.rounded() == reps.doubleValue,
                  let weight = sessionNumber(set["weight"]) else { return nil }
            sets.append(WorkoutWeightSet(reps: reps.intValue, weight: weight.doubleValue))
        }
        let session = WorkoutWeightSession(id: id, timestamp: timestamp.doubleValue, sets: sets)
        return session.isValid ? session : nil
    }
    func matches(reps: [Int]) -> Bool { sets.map(\.reps) == reps }

    private static func sessionNumber(_ value: Any?) -> NSNumber? {
        guard let number = value as? NSNumber, CFGetTypeID(number) != CFBooleanGetTypeID() else { return nil }
        return number
    }
}

/// Only unambiguous prescriptions; free-form trainer instructions remain unchanged.
func workoutRepetitions(from prescription: String) -> [Int] {
    let text = prescription.lowercased().replacingOccurrences(of: " ", with: "")
        .replacingOccurrences(of: "×", with: "x").replacingOccurrences(of: "–", with: "-")
    if text.range(of: "^[0-9]+(-[0-9]+)+$", options: .regularExpression) != nil {
        let reps = text.split(separator: "-").compactMap { Int($0) }
        return reps.count == text.split(separator: "-").count && (2...20).contains(reps.count)
            && reps.allSatisfy { (1...1000).contains($0) } ? reps : []
    }
    if text.range(of: "^[0-9]+x[0-9]+$", options: .regularExpression) != nil {
        let values = text.split(separator: "x").compactMap { Int($0) }
        if values.count == 2, (1...20).contains(values[0]), (1...1000).contains(values[1]) {
            return Array(repeating: values[1], count: values[0])
        }
    }
    return []
}

enum WorkoutWeightHistoryEntry: Identifiable {
    case single(WeightLog)
    case session(WorkoutWeightSession)
    var id: String {
        switch self { case .single(let log): return "single_" + log.id
        case .session(let session): return "session_" + session.id }
    }
    var date: Date {
        switch self { case .single(let log): return log.date
        case .session(let session): return session.date }
    }
}

struct WeightLog: Identifiable, Codable, Equatable {
    var id: String
    var timestamp: TimeInterval
    var weight: Double

    var date: Date {
        if timestamp > 10_000_000_000 { // Timestamp saved in milliseconds
            return Date(timeIntervalSince1970: timestamp / 1000)
        } else {
            return Date(timeIntervalSince1970: timestamp)
        }
    }

    var firebaseValue: [String: Any] {
        [
            "timestamp": timestamp,
            "weight": weight
        ]
    }

    static func parse(from data: [String: Any]) -> [WeightLog] {
        data.compactMap { key, value in
            guard let dictionary = value as? [String: Any] else { return nil }

            guard let timestamp = WeightLog.timestampValue(from: dictionary["timestamp"]),
                  let weight = WeightLog.doubleValue(from: dictionary["weight"]) else {
                return nil
            }

            return WeightLog(id: key, timestamp: timestamp, weight: weight)
        }
        .sorted { $0.timestamp < $1.timestamp }
    }

    private static func timestampValue(from value: Any?) -> TimeInterval? {
        if let doubleValue = value as? Double {
            return doubleValue
        }

        if let intValue = value as? Int {
            return TimeInterval(intValue)
        }

        if let stringValue = value as? String,
           let doubleValue = Double(stringValue) {
            return doubleValue
        }

        return nil
    }

    private static func doubleValue(from value: Any?) -> Double? {
        if let doubleValue = value as? Double {
            return doubleValue
        }

        if let intValue = value as? Int {
            return Double(intValue)
        }

        if let stringValue = value as? String {
            let normalized = stringValue.replacingOccurrences(of: ",", with: ".")
            return Double(normalized)
        }

        return nil
    }
}

class Esercizio: Identifiable, Codable {
    var id: String
    var name: String
    var serie: String
    var priorita: Int?
    var riposo: String?
    var notePT: String?
    var noteUtente: String?
    var weightLogs: [WeightLog]

    init(id: String, name: String, serie: String, priorita: Int? = nil, riposo: String? = nil, notePT: String? = nil, noteUtente: String? = nil, weightLogs: [WeightLog] = []) {
        self.id = id
        self.name = name
        self.serie = serie
        self.priorita = priorita
        self.riposo = riposo
        self.notePT = notePT
        self.noteUtente = noteUtente
        self.weightLogs = weightLogs
    }

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case serie
        case priorita
        case riposo
        case notePT
        case noteUtente
        case weightLogs
    }


    var description: String {
        return """
        Esercizio {
            id: \(id)
            name: \(name)
            serie: \(serie)
            priorita: \(priorita ?? -1)
            riposo: \(riposo ?? "")
            notePT: \(notePT ?? "")
            noteUtente: \(noteUtente ?? "")
            weightLogs: \(weightLogs)
        }
        """
    }

}
