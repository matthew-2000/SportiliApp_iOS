//
//  ContentView.swift
//  SportiliApp
//
//  Created by Matteo Ercolino on 03/10/24.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        VStack {
            Image(systemName: "globe")
                .imageScale(.large)
                .foregroundStyle(.tint)
            Text("Hello, world!")
                .montserrat(size: 17)
        }
        .padding()
    }
}

#Preview {
    ContentView()
}
