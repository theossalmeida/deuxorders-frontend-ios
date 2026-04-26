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
        case .completed: return "Concluído"
        case .canceled: return "Cancelado"
        }
    }

    var color: Color {
        switch self {
        case .received: return .blue
        case .pending: return Color(red: 184/255, green: 121/255, blue: 31/255)
        case .preparing: return .orange
        case .waitingPickupOrDelivery: return .purple
        case .completed: return DSColor.ok
        case .canceled: return DSColor.destructive
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

    enum CodingKeys: String, CodingKey {
        case id
        case deliveryDate
        case status
        case clientId
        case clientName
        case totalPaid
        case totalValue
        case items
        case references
        case delivery
        case deliveryAddress
        case paidAt
        case paidByUserName
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        deliveryDate = try container.decode(Date.self, forKey: .deliveryDate)
        status = try container.decode(OrderStatus.self, forKey: .status)
        clientId = try container.decode(String.self, forKey: .clientId)
        clientName = try container.decode(String.self, forKey: .clientName)
        totalPaid = try container.decode(Int.self, forKey: .totalPaid)
        totalValue = try container.decode(Int.self, forKey: .totalValue)
        items = try container.decode([OrderItem].self, forKey: .items)
        references = try container.decodeIfPresent([String].self, forKey: .references)
        deliveryAddress = try container.decodeIfPresent(String.self, forKey: .delivery)
            ?? container.decodeIfPresent(String.self, forKey: .deliveryAddress)
        paidAt = try container.decodeIfPresent(Date.self, forKey: .paidAt)
        paidByUserName = try container.decodeIfPresent(String.self, forKey: .paidByUserName)
    }

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

    enum CodingKeys: String, CodingKey {
        case deliveryDate
        case status
        case delivery = "delivery"
        case items
        case references
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(deliveryDate, forKey: .deliveryDate)
        try container.encodeIfPresent(status, forKey: .status)
        try container.encodeIfPresent(deliveryAddress, forKey: .delivery)
        try container.encodeIfPresent(items, forKey: .items)
        try container.encodeIfPresent(references, forKey: .references)
    }
}

struct UpdateOrderResult: Decodable {
    let order: Order
    let warnings: [String]

    enum CodingKeys: String, CodingKey {
        case response
        case warnings
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let order = try? container.decode(Order.self) {
            self.order = order
            self.warnings = []
            return
        }

        let keyed = try decoder.container(keyedBy: CodingKeys.self)
        self.order = try keyed.decode(Order.self, forKey: .response)
        self.warnings = try keyed.decodeIfPresent([String].self, forKey: .warnings) ?? []
    }
}

struct UpdateOrderItemRequest: Codable {
    let productId: String
    let quantity: Int?
    let paidUnitPrice: Int?
    let observation: String?
    let massa: String?
    let sabor: String?
}
