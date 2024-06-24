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
//                TextField("Riposo", text: $esercizio.riposo ?? "")
//                TextField("Note PT", text: $esercizio.notePT ?? "")
//                TextField("Note Utente", text: $esercizio.noteUtente ?? "")
//                Stepper(value: $esercizio.ordine ?? 0, in: 1...100) {
//                    Text("Ordine: \(esercizio.ordine ?? 0)")
//                }
            }
        }
        .navigationTitle("Dettagli Esercizio")
    }
}

struct EsercizioDetailView_Previews: PreviewProvider {
    static var previews: some View {
        EsercizioDetailView(esercizio: .constant(Esercizio(name: "Panca Piana", serie: "3x10", riposo: "60s", notePT: "", noteUtente: "", ordine: 1)))
    }
}
