//
//  UtentiViewModel.swift
//  SportiliApp
//
//  Created by Matteo Ercolino on 04/06/24.
//

import Foundation

class UtentiViewModel {
    
    @Published var utenti: ListaUtenti?
    private var utentiManager: UtentiManager = UtentiManager()
    
    init() {
        fetchUtenti()
    }

    func fetchUtenti() {
        
    }
}
