//
//  HomeView.swift
//  SportiliApp
//
//  Created by Matteo Ercolino on 31/05/24.
//

import SwiftUI
import FirebaseAuth

struct HomeView: View {
    
    @State private var nomeUtente: String?
    @StateObject private var schedaViewModel = SchedaViewModel()

    
    init() {
        // Set the appearance of the navigation bar title
        let appearance = UINavigationBarAppearance()
        appearance.titleTextAttributes = [.font : UIFont(name: "Montserrat-SemiBold", size: 18)!]
        appearance.largeTitleTextAttributes = [.font : UIFont(name: "Montserrat-Bold", size: 35)!]
        
        UINavigationBar.appearance().standardAppearance = appearance
        UINavigationBar.appearance().scrollEdgeAppearance = appearance
        UINavigationBar.appearance().compactAppearance = appearance
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                
                Spacer()
                
                if let scheda = schedaViewModel.scheda {
                    List {
                        
                        HStack(alignment: .firstTextBaseline) {
                            Text("Inizio: \(getDateString())")
                                .montserrat(size: 20)
                                .fontWeight(.semibold)
                            Text("x\(scheda.durata) sett.")
                                .montserrat(size: 25)
                                .foregroundColor(.accentColor)
                                .bold()
                        }
                        .padding(.top, 20)
                        .padding(.bottom, 20)
                        
                        ForEach(scheda.giorni, id: \.id) { giorno in
                            NavigationLink(destination: DayView(day: giorno)) {
                                DayRow(day: giorno)
                            }
                        }
                        

                    }
                    .listStyle(PlainListStyle())
                    .onAppear {
                        UITableView.appearance().separatorStyle = .none
                    }
                } else {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .accentColor))
                }
                
                Spacer()
                
            }
            .onAppear {
                // Aggiorna il nome utente quando la vista appare per la prima volta
                if let currentUser = Auth.auth().currentUser {
                    nomeUtente = currentUser.displayName
                }
            }
            .navigationTitle(getTitle())
            .navigationBarTitleDisplayMode(.large)
        }
    }
    
    func getTitle() -> String {
        if let nomeUtente = nomeUtente {
            return "Ciao \(nomeUtente)"
        } else {
            return "Home"
        }
    }
    
    func getDateString() -> String {
        let formatter1 = DateFormatter()
        formatter1.dateStyle = .short
        return formatter1.string(from: schedaViewModel.scheda?.dataInizio ?? Date())
    }
}

struct DayRow: View {
    var day: Giorno
    
    var body: some View {
        HStack {
            RoundedRectangle(cornerRadius: 5)
                .frame(width: 40, height: 40)
                .foregroundColor(.gray)
            
            VStack(alignment: .leading) {
                Text("Giorno \(day.name)")
                    .montserrat(size: 18)
                    .fontWeight(.semibold)
                Text(getGruppiString())
                    .montserrat(size: 15)
                    .fontWeight(.semibold)
                    .foregroundColor(.gray)
            }
            
            Spacer()
            
        }
        .padding()
    }
    
    func getGruppiString() -> String {
        var s = ""
        for g in day.gruppiMuscolari {
            s += "\(g.nome), "
        }
        return s
    }
}

#Preview {
    HomeView()
}
