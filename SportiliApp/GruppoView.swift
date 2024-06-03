//
//  GruppoView.swift
//  SportiliApp
//
//  Created by Matteo Ercolino on 02/06/24.
//

import SwiftUI

struct GruppoView: View {
    
    var gruppo: String
    
    var body: some View {
        VStack(spacing: 0) {
            
            List {
                
                NavigationLink(destination: EsercizioView()) {
                    EsercizioRow()
                }
                NavigationLink(destination: EsercizioView()) {
                    EsercizioRow()
                }
                NavigationLink(destination: EsercizioView()) {
                    EsercizioRow()
                }

            }
            .listStyle(PlainListStyle())
            .onAppear {
                UITableView.appearance().separatorStyle = .none
            }
            
            Spacer()
            
        }
        .navigationTitle(gruppo)
        .navigationBarTitleDisplayMode(.large)
    }
    
}

struct EsercizioRow: View {
    
    var body: some View {
        HStack {
            RoundedRectangle(cornerRadius: 5)
                .frame(width: 100, height: 100)
                .foregroundColor(.gray)
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Panca Piana")
                    .montserrat(size: 18)
                    .fontWeight(.semibold)
                Text("3x12")
                    .montserrat(size: 25)
                    .fontWeight(.bold)
                    .foregroundColor(.accentColor)
                Text("1'30'' riposo")
                    .montserrat(size: 18)
            }
            
            Spacer()
            
        }
        .padding()
    }
    
}

#Preview {
    GruppoView(gruppo: "Petto")
}
