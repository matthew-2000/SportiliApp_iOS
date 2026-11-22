//
//  ContentView.swift
//  SportiliApp
//
//  Created by Matteo Ercolino on 31/05/24.
//

import SwiftUI

struct ContentView: View {
    
    @State private var selected = 0
    @State private var showRest = false
    @ObservedObject private var rest = PhoneRestTimer.shared
    private let previewWorkout: Scheda?

    init(previewWorkout: Scheda? = nil) { self.previewWorkout = previewWorkout }

    var body: some View {
        TabView(selection: $selected) {
            NavigationStack {
                if let previewWorkout {
                    HomeView(schedaViewModel: SchedaViewModel(autoFetchOnInit: false, scheda: previewWorkout),
                        previewUserName: "Anteprima")
                } else {
                    HomeView()
                }
            }
                .safeAreaInset(edge: .bottom, spacing: 0) { recoveryBar }
                .tag(0)
                .tabItem {
                    Image(systemName: "list.clipboard.fill")
                    Text("Scheda")
                        .montserrat(size: 12)
                }

            NavigationStack {
                AlertsView()
            }
                .safeAreaInset(edge: .bottom, spacing: 0) { recoveryBar }
                .tag(1)
                .tabItem {
                    Image(systemName: "bell.fill")
                    Text("Avvisi")
                        .montserrat(size: 12)
                }

            NavigationStack {
                SettingsView()
            }
                .safeAreaInset(edge: .bottom, spacing: 0) { recoveryBar }
                .tag(2)
                .tabItem {
                    Image(systemName: "gearshape.fill")
                    Text("Impostazioni")
                        .montserrat(size: 12)
                }
        }
        .sheet(isPresented: $showRest) { TimerSheet(riposo: "") }
        .onReceive(SurfaceRoute.shared.$url) { url in
            guard let url, url.scheme == "sportiliapp" else { return }
            if url.host == "rest" {
                rest.reconcile()
                if !rest.isTimerPresented { showRest = true }
                Task { @MainActor in
                    if SurfaceRoute.shared.url == url { SurfaceRoute.shared.url = nil }
                }
            } else if url.host == "day" {
                selected = 0
            }
        }
    }

    private var recoveryBar: some View {
        RestTimerBar { if !rest.isTimerPresented { showRest = true } }
    }
}

#Preview {
    ContentView()
}
