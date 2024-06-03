//
//  GruppoView.swift
//  SportiliApp
//
//  Created by Matteo Ercolino on 02/06/24.
//

import SwiftUI

struct GruppoView: View {
    
    var gruppo: GruppoMuscolare
    
    var body: some View {
        VStack(spacing: 0) {
            
            List {
                
                ForEach(gruppo.esericizi, id: \.id) { esericizio in
                    NavigationLink(destination: EsercizioView(esercizio: esericizio)) {
                        EsercizioRow(esercizio: esericizio)
                    }
                }

            }
            .listStyle(PlainListStyle())
            .onAppear {
                UITableView.appearance().separatorStyle = .none
            }
            
            Spacer()
            
        }
        .navigationTitle(gruppo.nome)
        .navigationBarTitleDisplayMode(.large)
    }
    
}

struct EsercizioRow: View {
    
    var esercizio: Esercizio
    
    var body: some View {
        HStack {
            RoundedRectangle(cornerRadius: 5)
                .frame(width: 100, height: 100)
                .foregroundColor(.gray)
            
            VStack(alignment: .leading, spacing: 8) {
                Text(esercizio.name)
                    .montserrat(size: 18)
                    .fontWeight(.semibold)
                Text("\(esercizio.serie)x\(esercizio.rep)")
                    .montserrat(size: 25)
                    .fontWeight(.bold)
                    .foregroundColor(.accentColor)
                if let riposo = esercizio.riposo {
                    Text("\(riposo) riposo")
                        .montserrat(size: 18)
                }
            }
            
            Spacer()
            
        }
        .padding()
    }
    
}
