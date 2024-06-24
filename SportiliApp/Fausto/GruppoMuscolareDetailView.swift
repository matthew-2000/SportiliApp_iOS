//
//  GruppoMuscolareDetailView.swift
//  SportiliApp
//
//  Created by Matteo Ercolino on 24/06/24.
//

import SwiftUI

struct GruppoMuscolareDetailView: View {
    @Binding var gruppo: GruppoMuscolare
    @State private var showingAddSheet = false

    var body: some View {
        Form {
            Section(header: Text("Nome Gruppo Muscolare")) {
                TextField("Nome Gruppo Muscolare", text: $gruppo.nome)
            }
            
            Section(header: Text("Esercizi")) {
                List {
                    ForEach(gruppo.esercizi.indices, id: \.self) { index in
                        NavigationLink(destination: EsercizioDetailView(esercizio: $gruppo.esercizi[index])) {
                            VStack(alignment: .leading, content: {
                                Text(gruppo.esercizi[index].name.isEmpty ? "Nuovo Esercizio" : gruppo.esercizi[index].name)
                                Text(gruppo.esercizi[index].serie)
                            })
                            
                        }
                    }
                    .onDelete { indices in
                        gruppo.esercizi.remove(atOffsets: indices)
                        aggiornaOrdineEsercizi()
                    }
                    .onMove { source, destination in
                        gruppo.esercizi.move(fromOffsets: source, toOffset: destination)
                        aggiornaOrdineEsercizi()
                    }
                }
                
                Button(action: {
                    showingAddSheet = true
                }) {
                    Text("Aggiungi Esercizio")
                }
                .sheet(isPresented: $showingAddSheet) {
                    AddEsercizioView(gruppo: $gruppo)
                }
            }
        }
        .navigationTitle("\(gruppo.nome)")
    }
    
    private func aggiornaOrdineEsercizi() {
        for index in gruppo.esercizi.indices {
            gruppo.esercizi[index].ordine = index + 1
        }
    }
}

struct GruppoMuscolareDetailView_Previews: PreviewProvider {
    static var previews: some View {
        GruppoMuscolareDetailView(gruppo: .constant(GruppoMuscolare(nome: "Petto", esercizi: [])))
    }
}
