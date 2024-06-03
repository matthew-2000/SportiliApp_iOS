//
//  EsercizioView.swift
//  SportiliApp
//
//  Created by Matteo Ercolino on 02/06/24.
//

import SwiftUI

struct EsercizioView: View {
    
    var body: some View {
        VStack(alignment: .leading) {
            
            ZStack {
                
                RoundedRectangle(cornerRadius: 10)
                    .foregroundColor(.cardGray)
                
                VStack(alignment: .leading) {
                    
                    RoundedRectangle(cornerRadius: 5)
                        .frame(height: 150)
                        .foregroundColor(.white)
                    
                    VStack(alignment: .leading, spacing: 10) {
                        Text("3x12")
                            .montserrat(size: 30)
                            .fontWeight(.bold)
                            .foregroundColor(.accentColor)
                        Text("1'30'' riposo")
                            .montserrat(size: 18)
                            .fontWeight(.semibold)
                        VStack(alignment: .leading) {
                            Text("Note:")
                                .montserrat(size: 20)
                                .fontWeight(.bold)
                            Text("Lorem ipsum dolor sit amet, consectetur adipiscing elit. Maecenas laoreet lorem a justo consequat, ac fermentum sapien sodales. Quisque malesuada dolor ac dui congue egestas.")
                                .montserrat(size: 15)
                        }
                    }

                }
                .padding()
            }
            
            VStack(alignment: .leading) {
                Text("Note utente:")
                    .montserrat(size: 20)
                    .fontWeight(.bold)
                Text("Lorem ipsum dolor sit amet, consectetur adipiscing elit. Maecenas laoreet lorem a justo consequat, ac fermentum sapien sodales. Quisque malesuada dolor ac dui congue egestas.")
                    .montserrat(size: 15)
                Button("Aggiungi nota", action: {
                    
                })
                .buttonStyle(PrimaryButtonStyle())
            }
            
        }
        .padding()
        .navigationTitle("Panca piana")
        .navigationBarTitleDisplayMode(.large)
    }
    
}

#Preview {
    EsercizioView()
}
