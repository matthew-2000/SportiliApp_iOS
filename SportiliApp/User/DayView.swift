//
//  DayView.swift
//  SportiliApp
//
//  Created by Matteo Ercolino on 02/06/24.
//

import SwiftUI

struct DayView: View {
    @State var day: Giorno
    
    var body: some View {
        VStack(spacing: 0) {
            
            List {
                ForEach(day.gruppiMuscolari, id: \.id) { gruppo in
                    Section(header: GruppoRow(gruppo: gruppo)) {
                        ForEach(gruppo.esercizi, id: \.id) { esercizio in
                            NavigationLink(
                                destination: EsercizioView(
                                    giornoId: day.id,
                                    gruppoId: gruppo.id,
                                    esercizioId: esercizio.id,
                                    esercizio: esercizio
                                )
                            ) {
                                EsercizioRow(esercizio: esercizio)
                            }
                        }
                    }
                }
            }
            .listStyle(.automatic)
            .onAppear {
                UITableView.appearance().separatorStyle = .none
            }
        }
        .navigationTitle(Text("\(day.name)"))
        .navigationBarTitleDisplayMode(.large)
    }
}

struct GruppoRow: View {
    var gruppo: GruppoMuscolare
    
    var body: some View {
        Text(gruppo.nome)
            .montserrat(size: 20)
    }
}

struct EsercizioRow: View {

    var esercizio: Esercizio

    private struct IdentifiableImage: Identifiable {
        let id = UUID()
        let image: UIImage
    }

    @State private var selectedImage: IdentifiableImage?

    private var exerciseParts: [String] {
        exerciseNameParts(from: esercizio.name)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Se il nome dell'esercizio contiene più parti (separate da "+") lo mostriamo come superset
            if exerciseParts.count > 1 {
                SupersetLinkedRows(names: exerciseParts) { image in
                    selectedImage = IdentifiableImage(image: image)
                }
            } else {
                // Altrimenti layout singolo
                HStack(alignment: .center, spacing: 16) {
                    SingleExercisePreview(name: exerciseParts.first) { image in
                        selectedImage = IdentifiableImage(image: image)
                    }
                    .frame(width: 104, height: 104)

                    VStack(alignment: .leading, spacing: 8) {
                        Text(esercizio.name)
                            .montserrat(size: 18)
                            .fontWeight(.semibold)

                        InfoSection(esercizio: esercizio)
                    }

                    Spacer()
                }
            }

            // Info sotto al superset
            if exerciseParts.count > 1 {
                InfoSection(esercizio: esercizio)
                    .padding(.leading, 16)
            }
        }
        .fullScreenCover(item: $selectedImage) { selected in
            FullScreenImageView(image: selected.image)
        }
    }

}

// MARK: - Componenti private

private struct SingleExercisePreview: View {
    let name: String?
    let onImageTap: (UIImage) -> Void

    private var trimmedName: String {
        name?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }

    var body: some View {
        Group {
            if trimmedName.isEmpty {
                PlaceholderThumbnail()
            } else {
                ExerciseThumbnailView(name: trimmedName, size: 104, onImageTap: onImageTap)
            }
        }
    }
}

private struct SupersetLinkedRows: View {
    let names: [String]
    let onImageTap: (UIImage) -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            RoundedRectangle(cornerRadius: 3)
                .fill(Color.accentColor)
                .frame(width: 4)
                .padding(.vertical, 12)
                .frame(maxHeight: .infinity)

            VStack(spacing: 0) {
                ForEach(Array(names.enumerated()), id: \.offset) { index, name in
                    SupersetItemRow(name: name, onImageTap: onImageTap)

                    if index < names.count - 1 {
                        SupersetConnector()
                    }
                }
            }
            .background(Color.cardGray.opacity(0.12))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.accentColor.opacity(0.25), lineWidth: 1)
            )
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct SupersetItemRow: View {
    let name: String
    let onImageTap: (UIImage) -> Void

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var displayName: String {
        let fallback = trimmedName.isEmpty ? name : trimmedName
        return fallback.isEmpty ? "-" : fallback
    }

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            if trimmedName.isEmpty {
                PlaceholderThumbnail()
                    .frame(width: 88, height: 88)
            } else {
                ExerciseThumbnailView(name: trimmedName, size: 88, onImageTap: onImageTap)
            }

            Text(displayName)
                .montserrat(size: 17)
                .fontWeight(.semibold)
                .lineLimit(1)
                .multilineTextAlignment(.leading)

            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }
}

private struct SupersetConnector: View {
    var body: some View {
        ZStack {
            Rectangle()
                .fill(Color.accentColor.opacity(0.18))
                .frame(height: 1)
                .frame(maxWidth: .infinity)

            Image(systemName: "plus")
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(.accentColor)
                .padding(.vertical, 4)
        }
        .padding(.horizontal, 12)
        .frame(maxWidth: .infinity)
    }
}

private struct InfoSection: View {
    let esercizio: Esercizio

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("\(esercizio.serie)")
                .montserrat(size: 25)
                .fontWeight(.bold)
                .foregroundColor(.accentColor)

            if let riposo = esercizio.riposo, !riposo.isEmpty {
                Text("\(riposo) recupero")
                    .montserrat(size: 18)
            }
        }
    }
}

private struct ExerciseThumbnailView: View {
    let name: String
    let size: CGFloat
    let onImageTap: (UIImage) -> Void

    @StateObject private var imageLoader = ImageLoader()
    @State private var lastRequestedName: String = ""

    var body: some View {
        Group {
            if let image = imageLoader.image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: size, height: size)
                    .clipped()
                    .cornerRadius(5)
                    .onTapGesture {
                        onImageTap(image)
                    }
            } else if imageLoader.error != nil {
                PlaceholderThumbnail()
                    .frame(width: size, height: size)
            } else {
                ZStack {
                    RoundedRectangle(cornerRadius: 5)
                        .fill(Color.cardGray.opacity(0.3))
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .accentColor))
                }
                .frame(width: size, height: size)
            }
        }
        .onAppear {
            loadImageIfNeeded()
        }
        .onChange(of: name) { _ in
            loadImageIfNeeded()
        }
    }

    private func loadImageIfNeeded() {
        guard !PreviewContext.isPreview else { return }
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }

        if trimmedName != lastRequestedName {
            lastRequestedName = trimmedName
            let storagePath = "https://firebasestorage.googleapis.com/v0/b/sportiliapp.appspot.com/o/\(trimmedName).png"
            imageLoader.loadImage(from: storagePath)
        }
    }
}

private struct PlaceholderThumbnail: View {
    var body: some View {
        RoundedRectangle(cornerRadius: 5)
            .fill(Color.cardGray)
            .overlay(
                Image(systemName: "photo")
                    .foregroundColor(.white.opacity(0.7))
            )
    }
}

private func exerciseNameParts(from name: String) -> [String] {
    let components = name
        .split(separator: "+")
        .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        .filter { !$0.isEmpty }

    if !components.isEmpty {
        return components
    }

    let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
    return trimmed.isEmpty ? [] : [trimmed]
}

#Preview("Day View") {
    NavigationView {
        DayView(day: PreviewData.giorno)
    }
}

#Preview("Gruppo Row") {
    GruppoRow(gruppo: PreviewData.gruppo)
        .previewLayout(.sizeThatFits)
        .padding()
}

#Preview("Esercizio Row") {
    EsercizioRow(esercizio: PreviewData.singleExercise)
        .previewLayout(.sizeThatFits)
        .padding()
}
