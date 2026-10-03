//
//  SportiliAppApp.swift
//  SportiliApp
//
//  Created by Matteo Ercolino on 31/05/24.
//

import SwiftUI
import UIKit
import FirebaseCore
import FirebaseAuth

class AppDelegate: NSObject, UIApplicationDelegate {
  func application(_ application: UIApplication,
                   didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
    FirebaseApp.configure()
    return true
  }
}

@main
struct SportiliAppApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    
    var body: some Scene {
        WindowGroup {
            rootView
            .montserrat(size: 17)
        }
    }

    @ViewBuilder
    private var rootView: some View {
#if DEBUG
        if let preview = QA01Preview.current {
            preview.view
        } else if Auth.auth().currentUser != nil {
            ContentView()
        } else {
            LoginView()
        }
#else
        if Auth.auth().currentUser != nil {
            ContentView()
        } else {
            LoginView()
        }
#endif
    }
}

#if DEBUG
private enum QA01Preview: String {
    case active
    case expired
    case requested

    static var current: QA01Preview? {
        let prefix = "--qa-screen="
        guard let argument = ProcessInfo.processInfo.arguments.first(where: { $0.hasPrefix(prefix) }) else {
            return nil
        }
        return QA01Preview(rawValue: String(argument.dropFirst(prefix.count)))
    }

    @ViewBuilder
    var view: some View {
        NavigationStack {
            HomeView(
                schedaViewModel: SchedaViewModel(
                    autoFetchOnInit: false,
                    scheda: workout
                ),
                previewUserName: "Matteo"
            )
        }
    }

    private var workout: Scheda {
        switch self {
        case .active:
            PreviewData.activeScheda
        case .expired:
            PreviewData.expiredScheda
        case .requested:
            PreviewData.requestedScheda
        }
    }
}
#endif

struct MontserratFontModifier: ViewModifier {
    let size: CGFloat
    let relativeTo: Font.TextStyle
    
    func body(content: Content) -> some View {
        content.font(.custom("Montserrat-Regular", size: size, relativeTo: relativeTo))
    }
}

extension View {
    func montserrat(size: CGFloat, relativeTo: Font.TextStyle = .body) -> some View {
        self.modifier(MontserratFontModifier(size: size, relativeTo: relativeTo))
    }
}

enum SportiliPalette {
    static let brandAccent = Color(red: 1, green: 138 / 255, blue: 0)
    static let primary = adaptive(light: 0x9B4A00, dark: 0xFFB870)
    static let onPrimary = adaptive(light: 0xFFFFFF, dark: 0x351F08)
    static let background = adaptive(light: 0xFFFBF7, dark: 0x18120D)
    static let surface = adaptive(light: 0xFFFFFF, dark: 0x211A15)
    static let surfaceMuted = adaptive(light: 0xF2E5DA, dark: 0x3C3027)
    static let outline = adaptive(light: 0x806F62, dark: 0xA99484)
    static let onSurfaceMuted = adaptive(light: 0x51443A, dark: 0xD8C3B3)
    static let successContainer = adaptive(light: 0xD7F7DF, dark: 0x154B2A)
    static let onSuccessContainer = adaptive(light: 0x0A5425, dark: 0xB8F1C9)
    static let warningContainer = adaptive(light: 0xFFE2B8, dark: 0x593A00)
    static let onWarningContainer = adaptive(light: 0x633B00, dark: 0xFFDEA5)
    static let criticalContainer = adaptive(light: 0xFFDAD6, dark: 0x6F2A27)
    static let onCriticalContainer = adaptive(light: 0x8C1D18, dark: 0xFFDAD6)
    static let infoContainer = adaptive(light: 0xDCE7FF, dark: 0x173F70)
    static let onInfoContainer = adaptive(light: 0x174A84, dark: 0xD5E3FF)

    private static func adaptive(light: UInt32, dark: UInt32) -> Color {
        Color(uiColor: UIColor { traits in
            UIColor(rgb: traits.userInterfaceStyle == .dark ? dark : light)
        })
    }
}

enum SportiliSpacing {
    static let compact: CGFloat = 8
    static let small: CGFloat = 12
    static let standard: CGFloat = 16
    static let section: CGFloat = 24
    static let large: CGFloat = 32
    static let extraLarge: CGFloat = 48
}

enum SportiliTypography {
    static let headline = Font.custom("Montserrat-Bold", size: 26, relativeTo: .title)
    static let title = Font.custom("Montserrat-SemiBold", size: 18, relativeTo: .title3)
    static let body = Font.custom("Montserrat-Regular", size: 16, relativeTo: .body)
    static let bodySmall = Font.custom("Montserrat-Regular", size: 14, relativeTo: .subheadline)
    static let label = Font.custom("Montserrat-SemiBold", size: 14, relativeTo: .body)
}

private extension UIColor {
    convenience init(rgb: UInt32) {
        self.init(
            red: CGFloat((rgb >> 16) & 0xFF) / 255,
            green: CGFloat((rgb >> 8) & 0xFF) / 255,
            blue: CGFloat(rgb & 0xFF) / 255,
            alpha: 1
        )
    }
}

struct SportiliPrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(SportiliTypography.title)
            .foregroundStyle(SportiliPalette.onPrimary)
            .frame(maxWidth: .infinity, minHeight: 52)
            .padding(.horizontal, SportiliSpacing.standard)
            .background(SportiliPalette.primary.opacity(isEnabled ? 1 : 0.45))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .opacity(configuration.isPressed ? 0.82 : 1)
    }
}
