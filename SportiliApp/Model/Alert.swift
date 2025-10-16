import Foundation

struct UserAlert: Identifiable, Equatable {
    enum Urgency: String {
        case nessuna
        case bassa
        case media
        case alta

        var displayName: String {
            switch self {
            case .nessuna:
                return "Nessuna"
            case .bassa:
                return "Bassa"
            case .media:
                return "Media"
            case .alta:
                return "Alta"
            }
        }
    }

    let id: String
    let titolo: String
    let descrizione: String
    let scadenza: Date?
    let urgenza: Urgency

    init?(id: String, data: [String: Any]) {
        guard let titolo = data["titolo"] as? String,
              let descrizione = data["descrizione"] as? String else {
            return nil
        }

        let urgenzaString = (data["urgenza"] as? String)?.lowercased() ?? Urgency.nessuna.rawValue
        let urgenza = Urgency(rawValue: urgenzaString) ?? .nessuna

        let scadenzaMillis = data["scadenza"] as? TimeInterval
        let scadenzaDate: Date?
        if let scadenzaMillis {
            scadenzaDate = Date(timeIntervalSince1970: scadenzaMillis / 1000)
        } else {
            scadenzaDate = nil
        }

        self.id = id
        self.titolo = titolo
        self.descrizione = descrizione
        self.scadenza = scadenzaDate
        self.urgenza = urgenza
    }

    var isExpired: Bool {
        guard let scadenza else { return false }
        return scadenza < Date()
    }
}

extension Array where Element == UserAlert {
    func sortedByPriority() -> [UserAlert] {
        let urgencyOrder: [UserAlert.Urgency: Int] = [
            .alta: 0,
            .media: 1,
            .bassa: 2,
            .nessuna: 3
        ]

        return sorted { lhs, rhs in
            if lhs.urgenza != rhs.urgenza {
                return (urgencyOrder[lhs.urgenza] ?? 3) < (urgencyOrder[rhs.urgenza] ?? 3)
            }

            switch (lhs.scadenza, rhs.scadenza) {
            case let (lhsDate?, rhsDate?):
                return lhsDate < rhsDate
            case (nil, _?):
                return false
            case (_?, nil):
                return true
            default:
                return lhs.titolo < rhs.titolo
            }
        }
    }
}
