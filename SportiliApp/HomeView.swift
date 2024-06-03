//
//  HomeView.swift
//  SportiliApp
//
//  Created by Matteo Ercolino on 31/05/24.
//

import SwiftUI

struct HomeView: View {
    
    init() {
        // Set the appearance of the navigation bar title
        let appearance = UINavigationBarAppearance()
        appearance.titleTextAttributes = [.font : UIFont(name: "Montserrat-SemiBold", size: 18)!]
        appearance.largeTitleTextAttributes = [.font : UIFont(name: "Montserrat-Bold", size: 35)!]
        
        UINavigationBar.appearance().standardAppearance = appearance
        UINavigationBar.appearance().scrollEdgeAppearance = appearance
        UINavigationBar.appearance().compactAppearance = appearance
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                
                List {
                    
                    HStack(alignment: .firstTextBaseline) {
                        Text("Inizio: 30/02/2024")
                            .montserrat(size: 20)
                            .fontWeight(.semibold)
                        Text("x7 sett.")
                            .montserrat(size: 25)
                            .foregroundColor(.accentColor)
                            .bold()
                    }
                    .padding(.top, 20)
                    .padding(.bottom, 20)
                    
                    NavigationLink(destination: DayView(day: "A")) {
                        DayRow(day: "A")
                    }
                    
                    NavigationLink(destination: DayView(day: "B")) {
                        DayRow(day: "B")
                    }
                    
                    NavigationLink(destination: DayView(day: "C")) {
                        DayRow(day: "C")
                    }
                    

                }
                .listStyle(PlainListStyle())
                .onAppear {
                    UITableView.appearance().separatorStyle = .none
                }
                
                Spacer()
                
            }
            .navigationTitle("Home")
            .navigationBarTitleDisplayMode(.large)
        }
    }
}

struct DayRow: View {
    var day: String
    
    var body: some View {
        HStack {
            RoundedRectangle(cornerRadius: 5)
                .frame(width: 40, height: 40)
                .foregroundColor(.gray)
            
            VStack(alignment: .leading) {
                Text("Giorno \(day)")
                    .montserrat(size: 18)
                    .fontWeight(.semibold)
                Text("Pettorali, addominali, bicipiti")
                    .montserrat(size: 15)
                    .fontWeight(.semibold)
                    .foregroundColor(.gray)
            }
            
            Spacer()
            
        }
        .padding()
    }
}

#Preview {
    HomeView()
}
