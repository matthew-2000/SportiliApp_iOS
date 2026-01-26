//
//  ContentView.swift
//  SportiliApp
//
//  Created by Matteo Ercolino on 31/05/24.
//

import SwiftUI

struct ContentView: View {
    
    var body: some View {
        TabView {
            HomeView()
                .tabItem {
                    Image(systemName: "house.fill")
                    Text("Home")
                        .montserrat(size: 12)
                }

            AlertsView()
                .tabItem {
                    Image(systemName: "bell.badge.fill")
                    Text("Avvisi")
                        .montserrat(size: 12)
                }

            SettingsView()
                .tabItem {
                    Image(systemName: "gearshape.fill")
                    Text("Impostazioni")
                        .montserrat(size: 12)
                }
        }
    }
}

#Preview {
    ContentView()
}
