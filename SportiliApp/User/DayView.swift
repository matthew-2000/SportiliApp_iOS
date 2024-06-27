//
//  DayView.swift
//  SportiliApp
//
//  Created by Matteo Ercolino on 02/06/24.
//

import SwiftUI

struct DayView: View {
    @State var day: Giorno
    
    var body: some View {
        VStack(spacing: 0) {
            
            List {
                
                ForEach(day.gruppiMuscolari, id: \.id) { gruppo in
                    Section(header: GruppoRow(gruppo: gruppo)) {
                        ForEach(gruppo.esercizi, id: \.id) { esercizio in
                            NavigationLink(destination: EsercizioView(esercizio: esercizio)) {
                                EsercizioRow(esercizio: esercizio)
                            }
                        }
                    }
                }

            }
            .listStyle(PlainListStyle())
            .onAppear {
                UITableView.appearance().separatorStyle = .none
            }
            
            Spacer()
            
        }
        .navigationTitle("\(day.name)")
        .navigationBarTitleDisplayMode(.large)
    }
}

struct GruppoRow: View {
    var gruppo: GruppoMuscolare
    
    var body: some View {
        Text(gruppo.nome)
            .montserrat(size: 20)
            .bold()
    }
}

struct EsercizioRow: View {
    
    var esercizio: Esercizio
    @StateObject var imageLoader = ImageLoader()
    
    var body: some View {
        HStack {
            
            if let image = imageLoader.image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 100, height: 100)
                    .cornerRadius(5)
            } else {
                if imageLoader.error != nil {
                    RoundedRectangle(cornerRadius: 5)
                        .frame(width: 100, height: 100)
                        .foregroundColor(.gray)
                } else {
                    // Visualizza uno spinner o un messaggio di caricamento
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .accent))
                        .frame(width: 100, height: 100)
                }
            }
            
            VStack(alignment: .leading, spacing: 8) {
                if let ordine = esercizio.ordine {
                    HStack {
                        Text(esercizio.name)
                            .montserrat(size: 18)
                            .fontWeight(.semibold)
                        Spacer()
                        Text("\(ordine)°")
                            .montserrat(size: 15)
                            .fontWeight(.bold)
                    }
                } else {
                    Text(esercizio.name)
                        .montserrat(size: 18)
                        .fontWeight(.semibold)
                }
                Text("\(esercizio.serie)")
                    .montserrat(size: 25)
                    .fontWeight(.bold)
                    .foregroundColor(.accentColor)
                if let riposo = esercizio.riposo {
                    if !riposo.isEmpty {
                        Text("\(riposo) riposo")
                            .montserrat(size: 18)
                    }
                }
            }
            
            Spacer()
            
        }
        .onAppear {
            let storagePath = "https://firebasestorage.googleapis.com/v0/b/sportiliapp.appspot.com/o/\(esercizio.name).png"
            imageLoader.loadImage(from: storagePath)
        }
    }
    
}
