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
            Section(header: Text("Nome Gruppo Muscolare").montserrat(size: 17)) {
                TextField("Nome Gruppo Muscolare", text: $gruppo.nome)
                    .montserrat(size: 17)
            }
            
            Section(header: Text("Esercizi").montserrat(size: 17)) {
                List {
                    ForEach(gruppo.esercizi.indices, id: \.self) { index in
                        NavigationLink(destination: EsercizioDetailView(esercizio: $gruppo.esercizi[index])) {
                            VStack(alignment: .leading, content: {
                                Text(gruppo.esercizi[index].name.isEmpty ? "Nuovo Esercizio" : gruppo.esercizi[index].name)
                                    .montserrat(size: 17)
                                Text(gruppo.esercizi[index].serie)
                                    .montserrat(size: 15)
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
                        .montserrat(size: 17)
                }
                .sheet(isPresented: $showingAddSheet) {
                    AddEsercizioView(gruppo: $gruppo, nomeEsercizio: selectedEsercizio)
                }
                
            }
            
            Section(header: Text("Esercizi Predefiniti").montserrat(size: 17)) {
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
        .navigationTitle(Text("\(gruppo.nome)").montserrat(size: 20))
    }
    
    private func aggiornaOrdineEsercizi() {
        for _ in gruppo.esercizi.indices {
//            gruppo.esercizi[index].ordine = index + 1
        }
    }
}

struct EserciziPredefinitiRow: View {
    
    var esercizio: EsercizioPredefinito
    @StateObject var imageLoader = ImageLoader()
    
    var body: some View {
        HStack {
            Text(esercizio.nome)
                .montserrat(size: 17)
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
