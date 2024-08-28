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
    @ObservedObject var eserciziPredViewModel = EserciziPredefinitiViewModel()
    @State var selectedEsercizio = ""

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
                    AddEsercizioView(gruppo: $gruppo, nomeEsercizio: selectedEsercizio)
                }
                
            }
            
            Section(header: Text("Esercizi Predefiniti")) {
                List(eserciziPredViewModel.getGruppoMuscolare(named: gruppo.nome)?.esercizi ?? []) { esercizio in
                    if !gruppo.esercizi.contains(where: { $0.name == esercizio.nome }) {
                        Button(action: {
                            selectedEsercizio = esercizio.nome
                            showingAddSheet.toggle()
                        }, label: {
                            EserciziPredefinitiRow(esercizio: esercizio)
                        })
                    }
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

struct EserciziPredefinitiRow: View {
    
    var esercizio: EsercizioPredefinito
    @StateObject var imageLoader = ImageLoader()
    
    var body: some View {
        HStack {
            Text(esercizio.nome)
            Spacer()
//            if let image = imageLoader.image {
//                Image(uiImage: image)
//                    .resizable()
//                    .aspectRatio(contentMode: .fill)
//                    .frame(width: 50, height: 50)
//                    .cornerRadius(5)
//            } else {
//                if imageLoader.error != nil {
//                    // Mostra un'immagine fittizia quando si verifica un errore
//                    RoundedRectangle(cornerRadius: 5)
//                        .frame(width: 50, height: 50)
//                        .foregroundColor(.gray)
//                } else {
//                    // Visualizza uno spinner o un messaggio di caricamento
//                    ProgressView()
//                        .progressViewStyle(CircularProgressViewStyle(tint: .accent))
//                        .frame(width: 50, height: 50)
//                }
//            }
        }
        .onAppear {
//            let storagePath = "https://firebasestorage.googleapis.com/v0/b/sportiliapp.appspot.com/o/\(esercizio.nome).png"
//            imageLoader.loadImage(from: storagePath)
        }
    }
}

struct GruppoMuscolareDetailView_Previews: PreviewProvider {
    static var previews: some View {
        GruppoMuscolareDetailView(gruppo: .constant(GruppoMuscolare(nome: "Petto", esercizi: [])))
    }
}
