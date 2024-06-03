//
//  SettingsView.swift
//  SportiliApp
//
//  Created by Matteo Ercolino on 31/05/24.
//

import SwiftUI

struct SettingsView: View {
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                
                List {
                    
                    

                }
                .listStyle(PlainListStyle())

                .onAppear {
                    UITableView.appearance().separatorStyle = .none
                }
                
                Spacer()
                
            }
            .navigationTitle("Impostazioni")
            .navigationBarTitleDisplayMode(.large)
        }
    }
}

#Preview {
    SettingsView()
}
