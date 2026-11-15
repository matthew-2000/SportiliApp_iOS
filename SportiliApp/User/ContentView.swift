//
//  ContentView.swift
//  SportiliApp
//
//  Created by Matteo Ercolino on 31/05/24.
//

import SwiftUI

struct ContentView: View {
    
    @State private var selected = 0
    var body: some View {
        TabView(selection: $selected) {
            NavigationStack {
                HomeView()
            }
                .tag(0)
                .tabItem {
                    Image(systemName: "list.clipboard.fill")
                    Text("Scheda")
                        .montserrat(size: 12)
                }

            NavigationStack {
                AlertsView()
            }
                .tag(1)
                .tabItem {
                    Image(systemName: "bell.fill")
                    Text("Avvisi")
                        .montserrat(size: 12)
                }

            NavigationStack {
                SettingsView()
            }
                .tag(2)
                .tabItem {
                    Image(systemName: "gearshape.fill")
                    Text("Impostazioni")
                        .montserrat(size: 12)
                }
        }
        .onReceive(SurfaceRoute.shared.$url) { if $0 != nil { selected = 0 } }
    }
}

#Preview {
    ContentView()
}
