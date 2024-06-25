//
//  AdminContentView.swift
//  SportiliApp
//
//  Created by Matteo Ercolino on 25/06/24.
//

import SwiftUI

struct AdminContentView: View {
    var body: some View {
        TabView {
            AdminHomeView()
                .tabItem {
                    Image(systemName: "house.fill")
                    Text("Home")
                }
            
            SettingsView()
                .tabItem {
                    Image(systemName: "gearshape.fill")
                    Text("Impostazioni")
                }
        }
    }
}

#Preview {
    AdminContentView()
}
