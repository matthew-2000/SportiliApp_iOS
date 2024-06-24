//
//  GruppoMuscolareDetailView.swift
//  SportiliApp
//
//  Created by Matteo Ercolino on 24/06/24.
//

import SwiftUI

struct GruppoMuscolareDetailView: View {
    @Binding var gruppo: GruppoMuscolare
    
    var body: some View {
        Form {
            Section(header: Text("Nome Gruppo Muscolare")) {
                TextField("Nome Gruppo Muscolare", text: $gruppo.nome)
            }
            
            Section(header: Text("Esercizi")) {
                ForEach($gruppo.esercizi) { $esercizio in
                    NavigationLink(destination: EsercizioDetailView(esercizio: $esercizio)) {
                        Text(esercizio.name.isEmpty ? "Nuovo Esercizio" : esercizio.name)
                    }
                }
                
                Button(action: {
                    let nuovoEsercizio = Esercizio(name: "", serie: "", riposo: "", notePT: "", noteUtente: "", ordine: 1)
                    gruppo.esercizi.append(nuovoEsercizio)
                }) {
                    Text("Aggiungi Esercizio")
                }
            }
        }
        .navigationTitle("Dettagli Gruppo Muscolare")
    }
}

struct GruppoMuscolareDetailView_Previews: PreviewProvider {
    static var previews: some View {
        GruppoMuscolareDetailView(gruppo: .constant(GruppoMuscolare(nome: "Petto", esercizi: [])))
    }
}
