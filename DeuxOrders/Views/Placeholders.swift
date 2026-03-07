//
//  Placeholders.swift
//  DeuxOrders
//
//  Created by Theo on 04/03/26.
//

import SwiftUI

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
