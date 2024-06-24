//
//  AddEsercizioView.swift
//  SportiliApp
//
//  Created by Matteo Ercolino on 24/06/24.
//

import SwiftUI

struct AddEsercizioView: View {
    @Binding var gruppo: GruppoMuscolare
    @Environment(\.presentationMode) var presentationMode
    
    @State private var nomeEsercizio = ""
    @State private var serie = ""
    @State private var riposo = ""
    @State private var notePT = ""
    @State private var noteUtente = ""
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Dettagli Esercizio")) {
                    TextField("Nome Esercizio", text: $nomeEsercizio)
                    TextField("Serie", text: $serie)
                    TextField("Riposo", text: $riposo)
                    TextField("Note PT", text: $notePT)
                    TextField("Note Utente", text: $noteUtente)
                }
                
                Section {
                    Button(action: aggiungiEsercizio) {
                        Text("Aggiungi")
                    }
                    .disabled(nomeEsercizio.isEmpty)
                }
            }
            .navigationTitle("Nuovo Esercizio")
            .navigationBarItems(trailing: Button("Annulla") {
                presentationMode.wrappedValue.dismiss()
            })
        }
    }
    
    private func aggiungiEsercizio() {
        let nuovoEsercizio = Esercizio(name: nomeEsercizio, serie: serie, riposo: riposo, notePT: notePT, noteUtente: noteUtente, ordine: gruppo.esercizi.count + 1)
        gruppo.esercizi.append(nuovoEsercizio)
        presentationMode.wrappedValue.dismiss()
    }
}

#Preview {
    AddEsercizioView(gruppo: .constant(GruppoMuscolare(nome: "Petto", esercizi: [])))
}
