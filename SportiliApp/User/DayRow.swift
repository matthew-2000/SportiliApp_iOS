import SwiftUI

struct DayRow: View {
    let day: Giorno

    var body: some View {
        HStack(alignment: .top, spacing: SportiliSpacing.small) {
            Image(systemName: "figure.strengthtraining.traditional")
                .font(.title3.weight(.semibold))
                .foregroundStyle(SportiliPalette.primary)
                .frame(width: 28, height: 28)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 4) {
                Text(day.name)
                    .font(SportiliTypography.title)
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)

                if !gruppiString.isEmpty {
                    Text(gruppiString)
                        .font(SportiliTypography.bodySmall)
                        .foregroundStyle(SportiliPalette.onSurfaceMuted)
                        .lineLimit(2)
                }
            }
        }
        .padding(.vertical, SportiliSpacing.compact)
        .contentShape(Rectangle())
    }

    private var gruppiString: String {
        day.gruppiMuscolari
            .map(\.nome)
            .joined(separator: ", ")
    }
}

#Preview("Giorno") {
    DayRow(day: PreviewData.giorno)
        .padding()
}
