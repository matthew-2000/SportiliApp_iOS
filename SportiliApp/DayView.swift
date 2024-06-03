//
//  DayView.swift
//  SportiliApp
//
//  Created by Matteo Ercolino on 02/06/24.
//

import SwiftUI

struct DayView: View {
    var day: String
    
    var body: some View {
        VStack(spacing: 0) {
            
            List {
                
                NavigationLink(destination: GruppoView(gruppo: "Pettorali")) {
                    GruppoRow(gruppo: "Pettorali")
                }
                NavigationLink(destination: GruppoView(gruppo: "Pettorali")) {                    GruppoRow(gruppo: "Bicipiti")
                }
                NavigationLink(destination: GruppoView(gruppo: "Pettorali")) {                    GruppoRow(gruppo: "Addominali")
                }

            }
            .listStyle(PlainListStyle())
            .onAppear {
                UITableView.appearance().separatorStyle = .none
            }
            
            Spacer()
            
        }
        .navigationTitle("Giorno \(day)")
        .navigationBarTitleDisplayMode(.large)
    }
}

struct GruppoRow: View {
    var gruppo: String
    
    var body: some View {
        HStack {
            RoundedRectangle(cornerRadius: 5)
                .frame(width: 40, height: 40)
                .foregroundColor(.gray)
            
            Text(gruppo)
                .montserrat(size: 18)
                .fontWeight(.semibold)
            
            Spacer()
            
        }
        .padding()
    }
}

#Preview {
    DayView(day: "A")
}
