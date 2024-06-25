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
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                
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
                })
                .buttonStyle(DefaultButtonStyle())
                .controlSize(.regular)
                
            }
            .padding()
            .navigationTitle("Impostazioni")
            .navigationBarTitleDisplayMode(.large)
        }
        .fullScreenCover(isPresented: $isLoggedOut) {
            LoginView()
        }
    }
    
    func resetDefaults() {
        let defaults = UserDefaults.standard
        let dictionary = defaults.dictionaryRepresentation()
        dictionary.keys.forEach { key in
            defaults.removeObject(forKey: key)
        }
    }
}

#Preview {
    SettingsView()
}
