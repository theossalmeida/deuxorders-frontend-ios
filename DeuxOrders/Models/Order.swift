//
//  Order.swift
//  DeuxOrders
//
//  Created by Theo on 04/03/26.
//


import Foundation
import SwiftUI

enum OrderStatus: String, Codable, CaseIterable {
    case pending = "Pending"
    case completed = "Completed"
    case canceled = "Canceled"
    
    var localizedName: String {
        switch self {
        case .pending: return "Preparando"
        case .completed: return "Entregue"
        case .canceled: return "Cancelado"
        }
    }
    
    var color: Color {
        switch self {
        case .pending: return .yellow
        case .completed: return .green
        case .canceled: return .red
        }
    }
}

struct OrderResponse: Codable {
    let items: [Order]
    let totalCount: Int
    let pageNumber: Int
    let pageSize: Int
}

struct Order: Codable, Identifiable {
    let id: String
    let deliveryDate: Date
    var status: OrderStatus
    let clientId: String
    let clientName: String
    let totalPaid: Int
    let totalValue: Int
    let items: [OrderItem]
    let references: [String]?

    var shortId: String {
        String(id.prefix(8)).uppercased()
    }
}

struct OrderItem: Codable {
    let productId: String
    let productName: String
    let quantity: Int
    let paidUnitPrice: Int
    let baseUnitPrice: Int
    let totalPaid: Int
    let totalValue: Int
    let observation: String?
    let itemCanceled: Bool
}

struct UpdateOrderRequest: Codable {
    let deliveryDate: String?
    let status: Int?
    let items: [UpdateOrderItemRequest]?
    let references: [String]?
}

struct UpdateOrderItemRequest: Codable {
    let productId: String
    let quantity: Int?
    let paidUnitPrice: Int?
    let observation: String?
}
