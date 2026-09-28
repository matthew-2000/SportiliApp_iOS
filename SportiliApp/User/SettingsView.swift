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
            Section("Social") {
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
            }

            Section("Account") {
                Button(role: .destructive) {
                    isLogoutConfirmationPresented = true
                } label: {
                    Label("Esci dall’account", systemImage: "rectangle.portrait.and.arrow.right")
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                        .foregroundStyle(.red)
                }
                .accessibilityHint("Richiede conferma prima di terminare la sessione")
            }

            Section("Informazioni") {
                Label {
                    VStack(alignment: .leading, spacing: SportiliSpacing.compact) {
                        Text("Palestra Sportilia")
                            .font(SportiliTypography.label)
                        Text("Via Valle, 22\n83024 Monteforte Irpino (AV)\n338 7731977")
                            .font(SportiliTypography.bodySmall)
                            .foregroundStyle(SportiliPalette.onSurfaceMuted)
                    }
                } icon: {
                    Image(systemName: "mappin.and.ellipse")
                        .foregroundStyle(SportiliPalette.primary)
                }
                .accessibilityElement(children: .combine)

                LabeledContent("Versione", value: appVersion)
                LabeledContent("Build", value: buildNumber)
            }

            Section {
                Text("Made with ❤️ by Matteo Ercolino")
                    .font(SportiliTypography.bodySmall)
                    .foregroundStyle(SportiliPalette.onSurfaceMuted)
                    .frame(maxWidth: .infinity, alignment: .center)
            }
        }
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

    private func externalLinkRow(title: String, icon: String, url: String) -> some View {
        Button {
            openLink(url, name: title)
        } label: {
            HStack {
                Label(title, systemImage: icon)
                Spacer()
                if !sizeCategory.isAccessibilityCategory {
                    Image(systemName: "arrow.up.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(SportiliPalette.onSurfaceMuted)
                        .accessibilityHidden(true)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityHint("Apre \(title) fuori dall’app")
    }

    private func openLink(_ urlString: String, name: String) {
        guard let url = URL(string: urlString) else {
            showLinkError(for: name)
            return
        }

        openURL(url) { accepted in
            guard !accepted else { return }
            DispatchQueue.main.async {
                showLinkError(for: name)
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
