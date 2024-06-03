//
//  Giorno.swift
//  SportiliApp
//
//  Created by Matteo Ercolino on 03/06/24.
//

import Foundation

class Giorno {
    
    let id = UUID()
    var name: String
    var gruppiMuscolari: [GruppoMuscolare]
    
    init(name: String, gruppiMuscolari: [GruppoMuscolare]) {
        self.name = name
        self.gruppiMuscolari = gruppiMuscolari
    }
    
}
