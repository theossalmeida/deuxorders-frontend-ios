//
//  MainTabView.swift
//  DeuxOrders
//
//  Created by Theo on 04/03/26.
//

import SwiftUI

struct MainTabView: View {
    @StateObject private var ordersVM = OrdersViewModel(orderService: OrderService())
    @StateObject private var dashboardVM = DashboardViewModel()
    @StateObject private var cashFlowVM = CashFlowViewModel()

    var body: some View {
        TabView {
            DashboardView(viewModel: dashboardVM)
                .tabItem {
                    Label("Painel", systemImage: "chart.bar.xaxis")
                }

            OrdersView(viewModel: ordersVM)
                .tabItem {
                    Label("Pedidos", systemImage: "cart.fill")
                }

            NavigationStack {
                CashDashboardView(viewModel: cashFlowVM)
            }
            .tabItem {
                Label("Caixa", systemImage: "banknote")
            }

            ProductsView()
                .tabItem {
                    Label("Produtos", systemImage: "box.truck.fill")
                }

            ClientsView()
                .tabItem {
                    Label("Clientes", systemImage: "person.2.fill")
                }
        }
        .accentColor(DSColor.brand)
    }
}
