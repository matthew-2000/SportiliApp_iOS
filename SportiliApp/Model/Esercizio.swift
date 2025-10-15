//
//  Esercizio.swift
//  SportiliApp
//
//  Created by Matteo Ercolino on 03/06/24.
//

import Foundation

struct WeightLog: Identifiable, Codable {
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
