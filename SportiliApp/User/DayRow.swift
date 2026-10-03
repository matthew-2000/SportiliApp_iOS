import SwiftUI

struct DayRow: View {
    let day: Giorno
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        HStack(alignment: .top, spacing: SportiliSpacing.small) {
            if !dynamicTypeSize.isAccessibilitySize {
                Image(systemName: "figure.strengthtraining.traditional")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(SportiliPalette.primary)
                    .frame(minWidth: 28, minHeight: 28)
                    .fixedSize()
                    .accessibilityHidden(true)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(day.name)
                    .font(SportiliTypography.title)
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)

                if !gruppiString.isEmpty {
                    Text(gruppiString)
                        .font(SportiliTypography.bodySmall)
                        .foregroundStyle(SportiliPalette.onSurfaceMuted)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Text("Apri allenamento")
                    .font(SportiliTypography.labelSmall)
                    .foregroundStyle(SportiliPalette.primary)
            }
        }
        .padding(SportiliSpacing.standard)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(SportiliPalette.surface)
        .clipShape(RoundedRectangle(cornerRadius: SportiliShape.container, style: .continuous))
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
