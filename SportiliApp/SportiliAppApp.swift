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
    if let montserratFont = UIFont(name: "Montserrat-Regular", size: 17) {
        UILabel.appearance().font = montserratFont
        UITextField.appearance().font = montserratFont
        UITextView.appearance().font = montserratFont
        UIButton.appearance().titleLabel?.font = montserratFont
    }

    let navigationAppearance = UINavigationBarAppearance()
    navigationAppearance.titleTextAttributes = [.font: navigationTitleFont]
    navigationAppearance.largeTitleTextAttributes = [.font: navigationLargeTitleFont]

    let navigationBar = UINavigationBar.appearance()
    navigationBar.prefersLargeTitles = true
    navigationBar.standardAppearance = navigationAppearance
    navigationBar.scrollEdgeAppearance = navigationAppearance
    navigationBar.compactAppearance = navigationAppearance
    return true
  }

  private var navigationTitleFont: UIFont {
      UIFont(name: "Montserrat-SemiBold", size: 18) ?? .systemFont(ofSize: 18, weight: .semibold)
  }

  private var navigationLargeTitleFont: UIFont {
      UIFont(name: "Montserrat-Bold", size: 35) ?? .systemFont(ofSize: 35, weight: .bold)
  }
}

@main
struct SportiliAppApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    
    var body: some Scene {
        WindowGroup {
            Group {
                if Auth.auth().currentUser != nil {
                    ContentView()
                } else {
                    LoginView()
                }
            }
            .montserrat(size: 17)
        }
    }
}

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
