//
//  OrdersViewModel.swift
//  DeuxOrders
//
//  Created by Theo on 07/03/26.
//

import Foundation
import Combine

@MainActor
class OrdersViewModel: ObservableObject {
    @Published var orders: [Order] = []
    @Published var isLoading = false
    
    private let orderService: OrderService

    init(orderService: OrderService) {
        self.orderService = orderService
    }

    func loadOrders() async {
        isLoading = true
        
        defer { isLoading = false }
        
        do {
            self.orders = try await orderService.fetchOrders()
        } catch {
            print("API Error: \(error)")
        }
    }
}
