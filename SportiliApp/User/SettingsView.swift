//
//  SettingsView.swift
//  SportiliApp
//
//  Created by Matteo Ercolino on 31/05/24.
//

import FirebaseAuth
import SwiftUI

struct SettingsView: View {
    private struct PresentedError: Identifiable {
        let id = UUID()
        let title: String
        let message: String
    }

    @State private var isLoggedOut = false
    @State private var isLogoutConfirmationPresented = false
    @State private var presentedError: PresentedError?
    @Environment(\.openURL) private var openURL
    @Environment(\.sizeCategory) private var sizeCategory

    private let appVersion: String
    private let buildNumber: String
    private let signOut: () throws -> Void
    private let clearSessionDefaults: () -> Void

    init(
        appVersion: String = SettingsView.bundleValue(for: "CFBundleShortVersionString"),
        buildNumber: String = SettingsView.bundleValue(for: "CFBundleVersion"),
        signOut: @escaping () throws -> Void = { try Auth.auth().signOut() },
        clearSessionDefaults: @escaping () -> Void = SettingsView.resetSessionDefaults
    ) {
        self.appVersion = appVersion
        self.buildNumber = buildNumber
        self.signOut = signOut
        self.clearSessionDefaults = clearSessionDefaults
    }

    var body: some View {
        Form {
            Section {
                if sizeCategory.isAccessibilityCategory {
                    VStack(alignment: .leading, spacing: SportiliSpacing.small) {
                        contactIcon
                        contactDetails
                    }
                    .accessibilityElement(children: .combine)
                } else {
                    Label { contactDetails } icon: { contactIcon }
                        .accessibilityElement(children: .combine)
                }
            } header: {
                sectionHeader("Informazioni e contatti")
            }

            Section {
                externalLinkRow(
                    title: "Instagram",
                    icon: "camera.fill",
                    url: "https://www.instagram.com/sportiliacentrofitness"
                )

                externalLinkRow(
                    title: "Facebook",
                    icon: "person.2.fill",
                    url: "https://www.facebook.com/centrofitness.sportilia"
                )

                externalLinkRow(
                    title: "TikTok",
                    icon: "music.note",
                    url: "https://www.tiktok.com/@palestrasportilia"
                )

                externalLinkRow(
                    title: "Sito web",
                    icon: "globe",
                    url: "https://www.palestrasportilia.it"
                )
            } header: {
                sectionHeader("Link esterni")
            }

            Section {
                Button(role: .destructive) {
                    isLogoutConfirmationPresented = true
                } label: {
                    SettingsActionLabel(title: "Esci dall’account", icon: "rectangle.portrait.and.arrow.right")
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                        .foregroundStyle(SportiliPalette.onCriticalContainer)
                }
                .accessibilityHint("Richiede conferma prima di terminare la sessione")
            } header: {
                sectionHeader("Sessione")
            }

            Section {
                versionRow("Versione", value: appVersion)
                versionRow("Build", value: buildNumber)
            } header: {
                sectionHeader("Versione e build")
            }

            Section {
                Text("Made with ❤️ by Matteo Ercolino")
                    .font(SportiliTypography.bodySmall)
                    .foregroundStyle(SportiliPalette.onSurfaceMuted)
                    .frame(maxWidth: .infinity, alignment: .center)
            }
        }
        .font(SportiliTypography.body)
        .scrollContentBackground(.hidden)
        .background(SportiliPalette.background)
        .navigationTitle("Impostazioni")
        .navigationBarTitleDisplayMode(.large)
        .confirmationDialog(
            "Vuoi uscire dall’account?",
            isPresented: $isLogoutConfirmationPresented,
            titleVisibility: .visible
        ) {
            Button("Esci", role: .destructive, action: performLogout)
            Button("Annulla", role: .cancel) {}
        } message: {
            Text("Per accedere di nuovo dovrai inserire il tuo codice.")
        }
        .alert(item: $presentedError) { error in
            Alert(
                title: Text(error.title),
                message: Text(error.message),
                dismissButton: .default(Text("OK"))
            )
        }
        .fullScreenCover(isPresented: $isLoggedOut) {
            LoginView()
        }
    }

    private var contactIcon: some View {
        Image(systemName: "mappin.and.ellipse")
            .foregroundStyle(SportiliPalette.primary)
            .accessibilityHidden(true)
    }

    private var contactDetails: some View {
        VStack(alignment: .leading, spacing: SportiliSpacing.compact) {
            Text("Palestra Sportilia")
                .font(SportiliTypography.label)
            Text("Via Valle, 22\n83024 Monteforte Irpino (AV)\n338 7731977")
                .font(SportiliTypography.bodySmall)
                .foregroundStyle(SportiliPalette.onSurfaceMuted)
        }
        .fixedSize(horizontal: false, vertical: true)
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(SportiliTypography.label)
            .foregroundStyle(SportiliPalette.onSurfaceMuted)
            .textCase(nil)
            .fixedSize(horizontal: false, vertical: true)
    }

    @ViewBuilder
    private func externalLinkRow(title: String, icon: String, url: String) -> some View {
        if let destination = URL(string: url) {
            Link(destination: destination) {
                SettingsActionLabel(title: title, icon: icon, isExternal: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
            }
            .foregroundStyle(SportiliPalette.primary)
            .environment(\.openURL, OpenURLAction { destination in
                openURL(destination) { accepted in
                    guard !accepted else { return }
                    DispatchQueue.main.async { showLinkError(for: title) }
                }
                return .handled
            })
            .accessibilityHint("Apre \(title) fuori dall’app")
        }
    }

    @ViewBuilder
    private func versionRow(_ title: String, value: String) -> some View {
        if sizeCategory.isAccessibilityCategory {
            VStack(alignment: .leading, spacing: SportiliSpacing.compact) {
                Text(title)
                Text(value).foregroundStyle(SportiliPalette.onSurfaceMuted)
            }
            .accessibilityElement(children: .combine)
        } else {
            LabeledContent {
                Text(value).foregroundStyle(SportiliPalette.onSurfaceMuted)
            } label: {
                Text(title).foregroundStyle(SportiliPalette.onSurface)
            }
        }
    }

    private func showLinkError(for name: String) {
        presentedError = PresentedError(
            title: "Link non disponibile",
            message: "Non è stato possibile aprire \(name). Riprova più tardi."
        )
    }

    private func performLogout() {
        do {
            try signOut()
            clearSessionDefaults()
            isLoggedOut = true
        } catch {
            presentedError = PresentedError(
                title: "Impossibile uscire",
                message: "La sessione non è stata chiusa. Riprova."
            )
        }
    }

    private static func bundleValue(for key: String) -> String {
        Bundle.main.object(forInfoDictionaryKey: key) as? String ?? "—"
    }

    private static func resetSessionDefaults() {
        let defaults = UserDefaults.standard
        ["code", "isAdmin"].forEach(defaults.removeObject(forKey:))
    }
}

// At accessibility sizes, give the text the full row width below its symbols.
private struct SettingsActionLabel: View {
    let title: String
    let icon: String
    var isExternal = false
    @Environment(\.sizeCategory) private var sizeCategory

    var body: some View {
        if sizeCategory.isAccessibilityCategory {
            VStack(alignment: .leading, spacing: SportiliSpacing.small) {
                HStack {
                    Image(systemName: icon).accessibilityHidden(true)
                    Spacer()
                    externalIndicator
                }
                Text(title).fixedSize(horizontal: false, vertical: true)
            }
        } else {
            HStack(alignment: .firstTextBaseline, spacing: SportiliSpacing.small) {
                Label(title, systemImage: icon)
                Spacer(minLength: SportiliSpacing.compact)
                externalIndicator
            }
        }
    }

    @ViewBuilder
    private var externalIndicator: some View {
        if isExternal {
            Image(systemName: "arrow.up.right")
                .font(SportiliTypography.metadata)
                .foregroundStyle(SportiliPalette.onSurfaceMuted)
                .accessibilityHidden(true)
        }
    }
}

#Preview("Settings - Light") {
    NavigationStack {
        SettingsView(appVersion: "1.5.3", buildNumber: "15")
    }
}

#Preview("Settings - Dark") {
    NavigationStack {
        SettingsView(appVersion: "1.5.3", buildNumber: "15")
    }
    .preferredColorScheme(.dark)
}

#Preview("Settings - Accessibility text") {
    NavigationStack {
        SettingsView(appVersion: "1.5.3", buildNumber: "15")
    }
    .environment(\.sizeCategory, .accessibilityExtraExtraLarge)
}
