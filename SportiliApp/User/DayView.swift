//
//  DayView.swift
//  SportiliApp
//
//  Created by Matteo Ercolino on 02/06/24.
//

import SwiftUI

struct DayView: View {
    @State var day: Giorno
    var detailViewModel: ExerciseDetailViewModel? = nil
    var imageLoaderFactory: () -> ImageLoader = { ImageLoader() }
    var autoLoadImages: Bool = true
    
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
                                    esercizio: esercizio,
                                    viewModel: detailViewModel,
                                    imageLoader: imageLoaderFactory(),
                                    autoLoadImage: autoLoadImages
                                )
                            ) {
                                EsercizioRow(esercizio: esercizio, imageLoaderFactory: imageLoaderFactory, autoLoadImages: autoLoadImages)
                            }
                            .listRowSeparator(.hidden)
                        }
                    }
                }
            }
            .listStyle(.automatic)
        }
        .navigationTitle(Text("\(day.name)"))
        .navigationBarTitleDisplayMode(.large)
    }
}

struct GruppoRow: View {
    var gruppo: GruppoMuscolare
    
    var body: some View {
        Text(gruppo.nome)
            .font(SportiliTypography.title)
            .foregroundStyle(SportiliPalette.onSurfaceMuted)
            .textCase(nil)
            .fixedSize(horizontal: false, vertical: true)
    }
}

struct EsercizioRow: View {

    var esercizio: Esercizio
    var imageLoaderFactory: () -> ImageLoader = { ImageLoader() }
    var autoLoadImages: Bool = true
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

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
            if exerciseParts.count > 1 {
                Label("Superset · \(exerciseParts.count) parti", systemImage: "link")
                    .font(SportiliTypography.label)
                    .foregroundStyle(SportiliPalette.primary)
                InfoSection(esercizio: esercizio)
                SupersetLinkedRows(names: exerciseParts, imageLoaderFactory: imageLoaderFactory, autoLoadImages: autoLoadImages) { image in
                    selectedImage = IdentifiableImage(image: image)
                }
            } else {
                if dynamicTypeSize.isAccessibilitySize {
                    VStack(alignment: .leading, spacing: SportiliSpacing.small) {
                        singleTitle
                        thumbnail
                    }
                } else {
                    HStack(alignment: .top, spacing: SportiliSpacing.small) {
                        singleTitle
                        thumbnail
                    }
                }
            }
        }
        .padding(.vertical, SportiliSpacing.compact)
        .fullScreenCover(item: $selectedImage) { selected in
            FullScreenImageView(image: selected.image)
        }
    }

    private var singleTitle: some View {
        VStack(alignment: .leading, spacing: SportiliSpacing.small) {
            Text(esercizio.name)
                .font(SportiliTypography.title)
                .fixedSize(horizontal: false, vertical: true)
            InfoSection(esercizio: esercizio)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var thumbnail: some View {
        ExerciseThumbnailView(name: exerciseParts.first ?? "", size: 88,
            imageLoader: imageLoaderFactory(), autoLoadImage: autoLoadImages) { image in
            selectedImage = IdentifiableImage(image: image)
        }
    }

}

// MARK: - Componenti private

private struct SupersetLinkedRows: View {
    let names: [String]
    let imageLoaderFactory: () -> ImageLoader
    let autoLoadImages: Bool
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
                    SupersetItemRow(name: name, index: index, count: names.count, imageLoaderFactory: imageLoaderFactory, autoLoadImages: autoLoadImages, onImageTap: onImageTap)

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
    let index: Int
    let count: Int
    let imageLoaderFactory: () -> ImageLoader
    let autoLoadImages: Bool
    let onImageTap: (UIImage) -> Void
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var displayName: String {
        let fallback = trimmedName.isEmpty ? name : trimmedName
        return fallback.isEmpty ? "-" : fallback
    }

    var body: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: SportiliSpacing.small) {
                    partLabel
                    partThumbnail
                }
            } else {
                HStack(alignment: .center, spacing: SportiliSpacing.small) {
                    partThumbnail
                    partLabel
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }
    private var partLabel: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Parte \(index + 1) di \(count)")
                .font(SportiliTypography.labelSmall)
                .foregroundStyle(SportiliPalette.onSurfaceMuted)
            Text(displayName)
                .font(SportiliTypography.title)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var partThumbnail: some View {
        ExerciseThumbnailView(name: trimmedName, size: 64, imageLoader: imageLoaderFactory(),
            autoLoadImage: autoLoadImages, onImageTap: onImageTap)
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
        VStack(alignment: .leading, spacing: SportiliSpacing.compact) {
            Label {
                Text("Serie e ripetizioni: \(esercizio.serie)")
                    .font(SportiliTypography.title)
            } icon: {
                Image(systemName: "figure.strengthtraining.functional")
            }
            .foregroundStyle(SportiliPalette.primary)

            if let riposo = esercizio.riposo, !riposo.isEmpty {
                Label("Recupero \(riposo)", systemImage: "timer")
                    .font(SportiliTypography.bodySmall)
                    .foregroundStyle(SportiliPalette.onSurfaceMuted)
            }
        }
        .fixedSize(horizontal: false, vertical: true)
        .accessibilityElement(children: .combine)
    }
}

private struct ExerciseThumbnailView: View {
    let name: String
    let size: CGFloat
    let onImageTap: (UIImage) -> Void

    @StateObject private var imageLoader: ImageLoader
    let autoLoadImage: Bool

    init(name: String, size: CGFloat, imageLoader: ImageLoader = ImageLoader(),
         autoLoadImage: Bool = true, onImageTap: @escaping (UIImage) -> Void) {
        self.name = name
        self.size = size
        self.autoLoadImage = autoLoadImage
        self.onImageTap = onImageTap
        _imageLoader = StateObject(wrappedValue: imageLoader)
    }
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
                    .accessibilityLabel("Apri immagine di \(name) a schermo intero")
                    .accessibilityAddTraits(.isButton)
            } else if imageLoader.error != nil || (autoLoadImage && PreviewContext.isPreview) {
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
        guard autoLoadImage, !PreviewContext.isPreview else { return }
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
            .fill(SportiliPalette.surfaceMuted)
            .overlay(
                Image(systemName: "photo")
                    .foregroundStyle(SportiliPalette.onSurfaceMuted)
            )
            .accessibilityLabel("Immagine non disponibile")
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
    NavigationStack {
        DayView(day: PreviewData.giorno)
    }
}

#Preview("Gruppo Row") {
    GruppoRow(gruppo: PreviewData.gruppo)
        .padding()
}

#Preview("Esercizio Row") {
    EsercizioRow(esercizio: PreviewData.singleExercise)
        .padding()
}
