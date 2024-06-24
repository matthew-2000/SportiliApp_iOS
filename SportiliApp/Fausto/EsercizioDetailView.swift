//
//  EsercizioDetailView.swift
//  SportiliApp
//
//  Created by Matteo Ercolino on 24/06/24.
//

import SwiftUI

struct EsercizioDetailView: View {
    @Binding var esercizio: Esercizio
    
    var body: some View {
        Form {
            Section(header: Text("Dettagli Esercizio")) {
                TextField("Nome Esercizio", text: $esercizio.name)
                TextField("Serie", text: $esercizio.serie)
                TextField("Riposo", text: Binding(
                    get: { esercizio.riposo ?? "" },
                    set: { esercizio.riposo = $0 }
                ))
                
                TextField("Note PT", text: Binding(
                    get: { esercizio.notePT ?? "" },
                    set: { esercizio.notePT = $0 }
                ))
            }
        }
        .navigationTitle("\(esercizio.name)")
    }
}

struct EsercizioDetailView_Previews: PreviewProvider {
    static var previews: some View {
        EsercizioDetailView(esercizio: .constant(Esercizio(name: "Panca Piana", serie: "3x10", riposo: "60s", notePT: "", noteUtente: "", ordine: 1)))
    }
}
