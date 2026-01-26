//
//  GiornoDetailView.swift
//  SportiliApp
//
//  Created by Matteo Ercolino on 24/06/24.
//

import SwiftUI

struct GiornoDetailView: View {
    @Binding var giorno: Giorno
    @State private var showingAddGruppoMuscolareView = false
    
    var body: some View {
        Form {
            Section(header: Text("Nome Giorno").montserrat(size: 17)) {
                TextField("Nome Giorno", text: $giorno.name)
                    .montserrat(size: 17)
            }
            
            Section(header: Text("Gruppi Muscolari").montserrat(size: 17)) {
                ForEach($giorno.gruppiMuscolari) { $gruppo in
                    NavigationLink(destination: GruppoMuscolareDetailView(gruppo: $gruppo)) {
                        VStack(alignment: .leading) {
                            Text(gruppo.nome.isEmpty ? "Nuovo Gruppo Muscolare" : gruppo.nome)
                                .montserrat(size: 17)
                            Text("Numero esercizi: \(gruppo.esercizi.count)")
                                .montserrat(size: 15)
                        }
                    }
                }
                .onDelete { indices in
                    giorno.gruppiMuscolari.remove(atOffsets: indices)
                }
                .onMove { source, destination in
                    giorno.gruppiMuscolari.move(fromOffsets: source, toOffset: destination)
                }
                
                Button(action: {
                    showingAddGruppoMuscolareView.toggle()
                }) {
                    Text("Aggiungi Gruppo Muscolare")
                        .montserrat(size: 17)
                }
                .sheet(isPresented: $showingAddGruppoMuscolareView) {
                    AddGruppoMuscolareView(giorno: $giorno)
                }
            }
        }
        .navigationTitle(Text("\(giorno.name)").montserrat(size: 20))
    }
}

struct AddGruppoMuscolareView: View {
    @Binding var giorno: Giorno
    @Environment(\.presentationMode) var presentationMode
    @State private var selectedGruppoMuscolare = ""
    let gruppiMuscolariPredefiniti = [
      "Addominali",
      "Gambe e Glutei",
      "Polpacci",
      "Pettorali",
      "Spalle",
      "Dorsali",
      "Tricipiti",
      "Bicipiti",
      "Riscaldamento",
      "Defaticamento",
      "Cardio"
    ];

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Dettagli Gruppo Muscolare").montserrat(size: 17)) {
                    Picker("Seleziona Gruppo Muscolare", selection: $selectedGruppoMuscolare) {
                        ForEach(gruppiMuscolariPredefiniti, id: \.self) { gruppo in
                            if !giorno.gruppiMuscolari.contains(where: { $0.nome == gruppo }) {
                                Text(gruppo)
                                    .montserrat(size: 17)
                            }
                        }
                    }
                    .montserrat(size: 17)
                }
                
                Section {
                    Button(action: aggiungiGruppoMuscolare) {
                        Text("Aggiungi")
                            .montserrat(size: 17)
                    }
                    .disabled(selectedGruppoMuscolare.isEmpty)
                }
            }
            .navigationTitle(Text("Nuovo Gruppo Muscolare").montserrat(size: 20))
            .navigationBarItems(trailing: Button("Annulla") {
                presentationMode.wrappedValue.dismiss()
            }
            .montserrat(size: 17))
        }
        .interactiveDismissDisabled(true)
    }
    
    private func aggiungiGruppoMuscolare() {
        let nuovoGruppo = GruppoMuscolare(id: UUID().uuidString, nome: selectedGruppoMuscolare, esercizi: [])
        giorno.gruppiMuscolari.append(nuovoGruppo)
        presentationMode.wrappedValue.dismiss()
    }
}
