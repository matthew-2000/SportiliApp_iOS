//
//  GruppoMuscolare.swift
//  SportiliApp
//
//  Created by Matteo Ercolino on 03/06/24.
//

import Foundation

class GruppoMuscolare {
    
    var nome: String
    var esericizi: [Esercizio]
    
    
    init(nome: String, esericizi: [Esercizio]) {
        self.nome = nome
        self.esericizi = esericizi
    }
}
