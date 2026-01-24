import SwiftUI

struct DayRow: View {
    let day: Giorno

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(day.name)
                    .montserrat(size: 20)
                    .fontWeight(.semibold)
                Text(gruppiString)
                    .montserrat(size: 15)
                    .fontWeight(.semibold)
                    .foregroundColor(.gray)
            }

            Spacer()
        }
        .padding()
    }

    private var gruppiString: String {
        day.gruppiMuscolari
            .map(\.nome)
            .joined(separator: ", ")
    }
}

#Preview("Day Row") {
    DayRow(day: PreviewData.giorno)
        .previewLayout(.sizeThatFits)
}
