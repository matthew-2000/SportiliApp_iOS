//
//  DayView.swift
//  SportiliApp
//
//  Created by Matteo Ercolino on 02/06/24.
//

import SwiftUI

struct DayView: View {
    var day: Giorno
    
    var body: some View {
        VStack(spacing: 0) {
            
            List {
                
                ForEach(day.gruppiMuscolari, id: \.id) { gruppo in
                    NavigationLink(destination: GruppoView(gruppo: gruppo)) {
                        GruppoRow(gruppo: gruppo)
                    }
                }

            }
            .listStyle(PlainListStyle())
            .onAppear {
                UITableView.appearance().separatorStyle = .none
            }
            
            Spacer()
            
        }
        .navigationTitle("Giorno \(day.name)")
        .navigationBarTitleDisplayMode(.large)
    }
}

struct GruppoRow: View {
    var gruppo: GruppoMuscolare
    
    var body: some View {
        HStack {
            RoundedRectangle(cornerRadius: 5)
                .frame(width: 40, height: 40)
                .foregroundColor(.gray)
            
            Text(gruppo.nome)
                .montserrat(size: 18)
                .fontWeight(.semibold)
            
            Spacer()
            
        }
        .padding()
    }
}
