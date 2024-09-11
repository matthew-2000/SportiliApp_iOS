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
                .onMove { source, destination in
                    giorno.gruppiMuscolari.move(fromOffsets: source, toOffset: destination)
                }
                
                Button(action: {
                    showingAddGruppoMuscolareView.toggle()
                }) {
                    Text("Aggiungi Gruppo Muscolare")
                }
                .sheet(isPresented: $showingAddGruppoMuscolareView) {
                    AddGruppoMuscolareView(giorno: $giorno)
                }
            }
        }
        .navigationTitle("\(giorno.name)")
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
                Section(header: Text("Dettagli Gruppo Muscolare")) {
                    Picker("Seleziona Gruppo Muscolare", selection: $selectedGruppoMuscolare) {
                        ForEach(gruppiMuscolariPredefiniti, id: \.self) { gruppo in
                            if !giorno.gruppiMuscolari.contains(where: { $0.nome == gruppo }) {
                                Text(gruppo)
                            }
                        }
                    }
                }
                
                Section {
                    Button(action: aggiungiGruppoMuscolare) {
                        Text("Aggiungi")
                    }
                    .disabled(selectedGruppoMuscolare.isEmpty)
                }
            }
            .navigationTitle("Nuovo Gruppo Muscolare")
            .navigationBarItems(trailing: Button("Annulla") {
                presentationMode.wrappedValue.dismiss()
            })
        }
        .interactiveDismissDisabled(true)
    }
    
    private func aggiungiGruppoMuscolare() {
        let nuovoGruppo = GruppoMuscolare(nome: selectedGruppoMuscolare, esercizi: [])
        giorno.gruppiMuscolari.append(nuovoGruppo)
        presentationMode.wrappedValue.dismiss()
    }
}


struct GiornoDetailView_Previews: PreviewProvider {
    static var previews: some View {
        GiornoDetailView(giorno: .constant(Giorno(name: "Lunedì", gruppiMuscolari: [])))
    }
}
