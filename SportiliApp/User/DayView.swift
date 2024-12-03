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
                            NavigationLink(destination: EsercizioView(giornoId: day.id, gruppoId: gruppo.id, esercizioId: esercizio.id, esercizio: esercizio)) {
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
    @State private var showFullScreenImage = false
    
    var body: some View {
        HStack {
            
            if let image = imageLoader.image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 100, height: 100)
                    .cornerRadius(5)
                    .onTapGesture {
                        showFullScreenImage.toggle()
                    }
                    .fullScreenCover(isPresented: $showFullScreenImage) {
                        FullScreenImageView(image: image)
                    }
            } else {
                if imageLoader.error != nil {
                    RoundedRectangle(cornerRadius: 5)
                        .frame(width: 100, height: 100)
                        .foregroundColor(.cardGray)
                } else {
                    // Visualizza uno spinner o un messaggio di caricamento
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .accent))
                        .frame(width: 100, height: 100)
                }
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text(esercizio.name)
                    .montserrat(size: 18)
                    .fontWeight(.semibold)
                Text("\(esercizio.serie)")
                    .montserrat(size: 25)
                    .fontWeight(.bold)
                    .foregroundColor(.accentColor)
                if let riposo = esercizio.riposo {
                    if !riposo.isEmpty {
                        Text("\(riposo) recupero")
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
