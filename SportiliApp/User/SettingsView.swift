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
                        Button("Seguici su Instagram", action: {
                            if let url = URL(string: "https://www.instagram.com/sportiliacentrofitness") {
                                UIApplication.shared.open(url)
                            }
                        })
                        .montserrat(size: 15)
                        .fontWeight(.semibold)

                        Button("Seguici su Facebook", action: {
                            if let url = URL(string: "https://www.facebook.com/centrofitness.sportilia") {
                                UIApplication.shared.open(url)
                            }
                        })
                        .montserrat(size: 15)
                        .fontWeight(.semibold)
                    
                        Button(action: {
                            if let url = URL(string: "https://www.tiktok.com/@palestrasportilia") {
                                UIApplication.shared.open(url)
                            }
                        }, label: {
                            HStack {
                                Text("Seguici su Tik Tok")
                                    .montserrat(size: 15)
                                    .fontWeight(.semibold)
                            }
                        })

                        Button("Visita il sito web", action: {
                            if let url = URL(string: "https://www.palestrasportilia.it") {
                                UIApplication.shared.open(url)
                            }
                        })
                        .montserrat(size: 15)
                        .fontWeight(.semibold)
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
