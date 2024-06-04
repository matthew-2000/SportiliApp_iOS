//
//  AdminHomeView.swift
//  SportiliApp
//
//  Created by Matteo Ercolino on 04/06/24.
//

import SwiftUI

struct AdminHomeView: View {
    
    @StateObject private var utentiViewModel = UtentiViewModel()
    
    var body: some View {
        if let utenti = utentiViewModel.utenti {
            Text("\(utenti.utenti.first?.nome ?? "Peppe")")
            Button(action: {
                for utente in utenti.utenti {
                    
                }
            }, label: {
                /*@START_MENU_TOKEN@*/Text("Button")/*@END_MENU_TOKEN@*/
            })
        } else {
            Text("No")
        }
    }
}

#Preview {
    AdminHomeView()
}
