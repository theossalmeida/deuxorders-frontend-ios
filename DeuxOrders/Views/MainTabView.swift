//
//  MainTabView.swift
//  DeuxOrders
//
//  Created by Theo on 04/03/26.
//

import SwiftUI

struct MainTabView: View {
    var body: some View {
        TabView {
            // Aba 1: Dashboard
            DashboardView()
                .tabItem {
                    Label("Início", systemImage: "chart.bar.xaxis")
                }
            
            // Aba 2: Pedidos
            OrdersView()
                .tabItem {
                    Label("Pedidos", systemImage: "cart.fill")
                }
            
            // Aba 3: Produtos
            ProductsView()
                .tabItem {
                    Label("Produtos", systemImage: "box.truck.fill")
                }
            
            // Aba 4: Clientes
            ClientsView()
                .tabItem {
                    Label("Clientes", systemImage: "person.2.fill")
                }
        }
        // Cor principal da empresa nos ícones das abas
        .accentColor(.blue)
    }
}

#Preview {
    MainTabView()
}
