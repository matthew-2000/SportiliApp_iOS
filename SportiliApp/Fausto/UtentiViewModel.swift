//
//  UtentiViewModel.swift
//  SportiliApp
//
//  Created by Matteo Ercolino on 04/06/24.
//

import Foundation

class UtentiViewModel: ObservableObject {
    
    @Published var utenti: ListaUtenti?
    private var utentiManager: ListaUtentiManager = ListaUtentiManager()
    
    init() {
        fetchUtenti()
    }

    func fetchUtenti() {
        utentiManager.fetchAllUsers(completion: { utenti in
            DispatchQueue.main.async {
                self.utenti = utenti
            }
        })
    }
}
