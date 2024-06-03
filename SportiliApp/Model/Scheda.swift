//
//  Scheda.swift
//  SportiliApp
//
//  Created by Matteo Ercolino on 03/06/24.
//

import Foundation

class Scheda {
    
    var dataInizio: Date
    var durata: Int
    var giorni: [Giorno]
    
    init(dataInizio: Date, durata: Int, giorni: [Giorno]) {
        self.dataInizio = dataInizio
        self.durata = durata
        self.giorni = giorni
    }
    
}
