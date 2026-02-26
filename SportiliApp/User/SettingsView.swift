//
//  SettingsView.swift
//  SportiliApp
//
//  Created by Matteo Ercolino on 31/05/24.
//

import SwiftUI
import FirebaseAuth

struct SettingsView: View {
    
    @State private var isLoggedOut: Bool = false
    @Environment(\.openURL) private var openURL
    
    var body: some View {
        VStack(spacing: 0) {
            Form {
                Section(header: Text("Sportilia")
                    .montserrat(size: 13), content: {
                    HStack {
                        Spacer()
                        Text("PALESTRA SPORTILIA \nvia Valle, 22 83024 \nMonteforte Irpino (Avellino) \ncell. 338 7731977")
                            .montserrat(size: 15)
                            .multilineTextAlignment(.center)
                        Spacer()
                    }
                    .padding()
                })
                
                Section(header: Text("Social")
                    .montserrat(size: 13),
                        content: {
                    Button("Seguici su Instagram") {
                        openLink("https://www.instagram.com/sportiliacentrofitness")
                    }
                    .montserrat(size: 15)
                    .fontWeight(.semibold)
                    .accessibilityHint("Apre Instagram in Safari")

                    Button("Seguici su Facebook") {
                        openLink("https://www.facebook.com/centrofitness.sportilia")
                    }
                    .montserrat(size: 15)
                    .fontWeight(.semibold)
                    .accessibilityHint("Apre Facebook in Safari")
                
                    Button("Seguici su Tik Tok") {
                        openLink("https://www.tiktok.com/@palestrasportilia")
                    }
                    .montserrat(size: 15)
                    .fontWeight(.semibold)
                    .accessibilityHint("Apre TikTok in Safari")

                    Button("Visita il sito web") {
                        openLink("https://www.palestrasportilia.it")
                    }
                    .montserrat(size: 15)
                    .fontWeight(.semibold)
                    .accessibilityHint("Apre il sito ufficiale in Safari")
                })
                
                Section(header: Text("Logout")
                    .montserrat(size: 13), content: {
                    Button(action: {
                        let firebaseAuth = Auth.auth()
                        do {
                            try firebaseAuth.signOut()
                            resetDefaults()
                            isLoggedOut.toggle()
                        } catch let signOutError as NSError {
                          print("Error signing out: %@", signOutError)
                        }
                    }, label: {
                        Text("Logout")
                            .montserrat(size: 18)
                            .fontWeight(.semibold)
                    })
                    .accessibilityHint("Termina la sessione corrente")
                })
                
                Section(header: Text("Credits")
                    .montserrat(size: 13), content: {
                    HStack {
                        Spacer()
                        Text("Made with ❤️ by Matteo Ercolino")
                            .montserrat(size: 13)
                        Spacer()
                    }
                })
            }
        }
        .navigationTitle(Text("Impostazioni"))
        .navigationBarTitleDisplayMode(.large)
        .fullScreenCover(isPresented: $isLoggedOut) {
            LoginView()
        }
    }

    private func openLink(_ urlString: String) {
        guard let url = URL(string: urlString) else { return }
        openURL(url)
    }
    
    func resetDefaults() {
        let defaults = UserDefaults.standard
        let keysToReset = ["code", "isAdmin"]
        keysToReset.forEach { key in
            defaults.removeObject(forKey: key)
        }
    }
}

#Preview {
    SettingsView()
}
