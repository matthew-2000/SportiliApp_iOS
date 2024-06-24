//
//  GiornoDetailView.swift
//  SportiliApp
//
//  Created by Matteo Ercolino on 24/06/24.
//

import SwiftUI

struct GiornoDetailView: View {
    @Binding var giorno: Giorno
    @State private var showingAddSheet = false
    @State private var selectedGruppoMuscolare = "Petto"
    let gruppiMuscolariPredefiniti = ["Petto", "Dorso", "Gambe", "Spalle", "Bicipiti", "Tricipiti", "Addominali", "Cardio", "Defaticamento"]

    var body: some View {
        Form {
            Section(header: Text("Nome Giorno")) {
                TextField("Nome Giorno", text: $giorno.name)
            }
            
            Section(header: Text("Gruppi Muscolari")) {
                ForEach($giorno.gruppiMuscolari) { $gruppo in
                    NavigationLink(destination: GruppoMuscolareDetailView(gruppo: $gruppo)) {
                        VStack(alignment: .leading) {
                            Text(gruppo.nome.isEmpty ? "Nuovo Gruppo Muscolare" : gruppo.nome)
                            Text("Numero esercizi: \(gruppo.esercizi.count)")
                        }
                    }
                }
                .onDelete { indices in
                    giorno.gruppiMuscolari.remove(atOffsets: indices)
                }
                
                Button(action: {
                    showingAddSheet = true
                }) {
                    Text("Aggiungi Gruppo Muscolare")
                }
            }
        }
        .navigationTitle("\(giorno.name)")
        .sheet(isPresented: $showingAddSheet) {
            AddGruppoMuscolareView(giorno: $giorno)
        }
    }
}

struct AddGruppoMuscolareView: View {
    @Binding var giorno: Giorno
    @Environment(\.presentationMode) var presentationMode
    
    @State private var nomeGruppo = ""
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Dettagli Gruppo Muscolare")) {
                    TextField("Nome Gruppo Muscolare", text: $nomeGruppo)
                }
                
                Section {
                    Button(action: aggiungiGruppoMuscolare) {
                        Text("Aggiungi")
                    }
                    .disabled(nomeGruppo.isEmpty)
                }
            }
            .navigationTitle("Nuovo Gruppo Muscolare")
            .navigationBarItems(trailing: Button("Annulla") {
                presentationMode.wrappedValue.dismiss()
            })
        }
    }
    
    private func aggiungiGruppoMuscolare() {
        let nuovoGruppo = GruppoMuscolare(nome: nomeGruppo, esercizi: [])
        giorno.gruppiMuscolari.append(nuovoGruppo)
        presentationMode.wrappedValue.dismiss()
    }
}


struct GiornoDetailView_Previews: PreviewProvider {
    static var previews: some View {
        GiornoDetailView(giorno: .constant(Giorno(name: "Lunedì", gruppiMuscolari: [])))
    }
}
