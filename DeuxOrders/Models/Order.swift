//
//  Order.swift
//  DeuxOrders
//
//  Created by Theo on 04/03/26.
//


import Foundation
import SwiftUI

enum OrderStatus: String, Codable, CaseIterable {
    case received = "Received"
    case pending = "Pending"
    case preparing = "Preparing"
    case waitingPickupOrDelivery = "WaitingPickupOrDelivery"
    case completed = "Completed"
    case canceled = "Canceled"

    var localizedName: String {
        switch self {
        case .received: return "Recebido"
        case .pending: return "Pendente"
        case .preparing: return "Preparando"
        case .waitingPickupOrDelivery: return "Aguardando Retirada/Entrega"
        case .completed: return "Entregue"
        case .canceled: return "Cancelado"
        }
    }

    var color: Color {
        switch self {
        case .received: return .blue
        case .pending: return .orange
        case .preparing: return .yellow
        case .waitingPickupOrDelivery: return .purple
        case .completed: return .green
        case .canceled: return .red
        }
    }

    var intValue: Int {
        switch self {
        case .pending: return 1
        case .completed: return 2
        case .canceled: return 3
        case .received: return 4
        case .preparing: return 5
        case .waitingPickupOrDelivery: return 6
        }
    }
}

struct OrderResponse: Decodable {
    let items: [Order]
    let totalCount: Int
    let pageNumber: Int
    let pageSize: Int
}

struct Order: Decodable, Identifiable {
    let id: String
    let deliveryDate: Date
    var status: OrderStatus
    let clientId: String
    let clientName: String
    let totalPaid: Int
    let totalValue: Int
    let items: [OrderItem]
    let references: [String]?
    let deliveryAddress: String?
    let paidAt: Date?
    let paidByUserName: String?

    var shortId: String {
        String(id.prefix(8)).uppercased()
    }

    var isPaid: Bool {
        paidAt != nil
    }

    /// Next logical status in the pipeline (Received -> Preparing -> WaitingPickupOrDelivery -> Completed)
    var nextStatus: OrderStatus? {
        switch status {
        case .received: return .preparing
        case .pending: return .preparing
        case .preparing: return .waitingPickupOrDelivery
        case .waitingPickupOrDelivery: return .completed
        case .completed, .canceled: return nil
        }
    }
}

struct OrderItem: Decodable {
    let productId: String
    let productName: String
    let productSize: String?
    let quantity: Int
    let paidUnitPrice: Int
    let baseUnitPrice: Int
    let totalPaid: Int
    let totalValue: Int
    let observation: String?
    let itemCanceled: Bool
    let massa: String?
    let sabor: String?
}

struct UpdateOrderRequest: Codable {
    let deliveryDate: String?
    let status: Int?
    let deliveryAddress: String?
    let items: [UpdateOrderItemRequest]?
    let references: [String]?
}

struct UpdateOrderItemRequest: Codable {
    let productId: String
    let quantity: Int?
    let paidUnitPrice: Int?
    let observation: String?
    let massa: String?
    let sabor: String?
}
