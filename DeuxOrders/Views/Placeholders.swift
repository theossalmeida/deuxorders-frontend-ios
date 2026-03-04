//
//  Placeholders.swift
//  DeuxOrders
//
//  Created by Theo on 04/03/26.
//

import SwiftUI

struct OrdersView: View {
    var body: some View {
        NavigationStack {
            List(0..<10) { i in
                Text("Pedido #\(1000 + i)")
            }
            .navigationTitle("Pedidos")
        }
    }
}

struct ProductsView: View {
    var body: some View {
        NavigationStack {
            Text("Gestão de Estoque")
                .navigationTitle("Produtos")
        }
    }
}

struct ClientsView: View {
    var body: some View {
        NavigationStack {
            Text("Base de Clientes")
                .navigationTitle("Clientes")
        }
    }
}
