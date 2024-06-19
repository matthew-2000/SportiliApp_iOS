//
//  UtenteView.swift
//  SportiliApp
//
//  Created by Matteo Ercolino on 19/06/24.
//

import SwiftUI

struct UtenteView: View {
    @State var utente: Utente
    @ObservedObject var gymViewModel: GymViewModel
    
    var body: some View {
        VStack {
            Text("Boh")
        }
        .navigationTitle("\(utente.nome) \(utente.cognome)")
    }
}
