import SwiftUI

// Watch uses the same warm accent as iPhone, with native type and scalable controls.
enum WatchStyle {
    static let accent = Color(red: 1, green: 0.56, blue: 0.14)
    static let surface = Color(red: 0.12, green: 0.12, blue: 0.13)
    static let warmSurface = Color(red: 0.20, green: 0.14, blue: 0.09)
    static var card: LinearGradient {
        LinearGradient(colors: [Color(white: 0.16), surface], startPoint: .topLeading, endPoint: .bottomTrailing)
    }
    static var accentCard: LinearGradient {
        LinearGradient(colors: [warmSurface, surface], startPoint: .topLeading, endPoint: .bottomTrailing)
    }
}

struct WatchSectionTitle: View {
    let text: String
    var body: some View {
        Text(text).font(.caption2.weight(.semibold)).foregroundStyle(WatchStyle.accent)
    }
}

extension View {
    func watchCard(accented: Bool = false) -> some View {
        listRowBackground(RoundedRectangle(cornerRadius: 20, style: .continuous)
            .fill(accented ? WatchStyle.accentCard : WatchStyle.card))
    }
}

struct WatchNumberBadge: View {
    let number: Int
    var body: some View {
        Text(number, format: .number.precision(.integerLength(2)))
            .font(.system(.title3, design: .rounded, weight: .semibold))
            .foregroundStyle(WatchStyle.accent)
            .frame(width: 40, height: 40)
            .background(WatchStyle.accent.opacity(0.12), in: Circle())
            .accessibilityHidden(true)
    }
}

// Keep user-facing sync wording separate from stored receipts and transport errors.
enum WatchRecordingText {
    static func title(for status: WatchReceiptStatus?) -> String {
        switch status {
        case nil: "In attesa di invio"
        case .delivered: "Ricevuti da iPhone"
        case .saved: "Pesi salvati"
        case .retry: "Invio da riprovare"
        case .rejected: "Invio bloccato"
        case .conflict: "Controlla su iPhone"
        }
    }
    static func message(for item: WatchQueueItem, activeBinding: String?) -> String {
        if item.needsSync && item.recording.binding != activeBinding {
            return "L’accesso su iPhone è cambiato. Questi pesi restano sul Watch."
        }
        switch item.receipt?.status {
        case nil: return "Solo sul Watch. L’invio riparte quando l’iPhone è disponibile."
        case .delivered: return "Ricevuto dall’iPhone. Salvataggio non ancora confermato."
        case .saved: return "Salvataggio confermato."
        case .retry: return "Salvataggio non riuscito. Controlla internet su iPhone e tocca Riprova invio."
        case .rejected: return "Invio bloccato: l’accesso su iPhone è cambiato. I pesi restano qui."
        case .conflict: return "Questa registrazione è diversa su iPhone. Controlla lo storico dei pesi."
        }
    }
}
