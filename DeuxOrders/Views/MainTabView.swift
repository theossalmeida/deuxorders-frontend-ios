//
//  MainTabView.swift
//  DeuxOrders
//
//  Created by Theo on 04/03/26.
//

import SwiftUI

struct MainTabView: View {
    @StateObject private var ordersVM = OrdersViewModel(orderService: OrderService())
    @StateObject private var cashFlowVM = CashFlowViewModel()

    var body: some View {
        TabView {
            OrdersView(viewModel: ordersVM)
                .tabItem {
                    Label("Pedidos", systemImage: "cart.fill")
                }

            InventoryView()
                .tabItem {
                    Label("Estoque", systemImage: "shippingbox.fill")
                }

            NavigationStack {
                CashDashboardView(viewModel: cashFlowVM)
            }
            .tabItem {
                Label("Caixa", systemImage: "banknote")
            }
        }
        .accentColor(DSColor.brand)
    }
}
