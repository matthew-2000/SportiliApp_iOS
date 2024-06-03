//
//  SportiliAppApp.swift
//  SportiliApp
//
//  Created by Matteo Ercolino on 31/05/24.
//

import SwiftUI
import FirebaseCore

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
            ContentView()
        }
    }
}

struct MontserratFontModifier: ViewModifier {
    let size: CGFloat
    
    func body(content: Content) -> some View {
        content
            .font(.custom("Montserrat-Regular", size: size))
    }
}

extension View {
    func montserrat(size: CGFloat) -> some View {
        self.modifier(MontserratFontModifier(size: size))
    }
}
