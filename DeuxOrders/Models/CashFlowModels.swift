//
//  CashFlowModels.swift
//  DeuxOrders
//

import Foundation
import SwiftUI

// MARK: - Enums

enum CashFlowEntryType: String, Codable, CaseIterable {
    case inflow = "Inflow"
    case outflow = "Outflow"

    var localizedName: String {
        switch self {
        case .inflow: return "Entrada"
        case .outflow: return "Saída"
        }
    }

    var color: Color {
        switch self {
        case .inflow: return .green
        case .outflow: return .red
        }
    }

    var icon: String {
        switch self {
        case .inflow: return "arrow.up.right"
        case .outflow: return "arrow.down.left"
        }
    }
}

enum CashFlowCategory: String, Codable, CaseIterable {
    case order = "Order"
    case orderReversal = "OrderReversal"
    case rawMaterial = "RawMaterial"
    case supplier = "Supplier"
    case salary = "Salary"
    case tax = "Tax"
    case utilities = "Utilities"
    case equipment = "Equipment"
    case marketing = "Marketing"
    case other = "Other"

    var localizedName: String {
        switch self {
        case .order: return "Pedido"
        case .orderReversal: return "Estorno de Pedido"
        case .rawMaterial: return "Matéria-Prima"
        case .supplier: return "Fornecedor"
        case .salary: return "Salário"
        case .tax: return "Imposto"
        case .utilities: return "Serviços/Utilidades"
        case .equipment: return "Equipamento"
        case .marketing: return "Marketing"
        case .other: return "Outros"
        }
    }

    var color: Color {
        switch self {
        case .order: return .green
        case .orderReversal: return .orange
        case .rawMaterial: return .brown
        case .supplier: return .blue
        case .salary: return .purple
        case .tax: return .red
        case .utilities: return .cyan
        case .equipment: return .indigo
        case .marketing: return .pink
        case .other: return .gray
        }
    }

    var icon: String {
        switch self {
        case .order: return "cart.fill"
        case .orderReversal: return "arrow.uturn.backward"
        case .rawMaterial: return "leaf.fill"
        case .supplier: return "shippingbox.fill"
        case .salary: return "person.fill"
        case .tax: return "doc.text.fill"
        case .utilities: return "bolt.fill"
        case .equipment: return "wrench.fill"
        case .marketing: return "megaphone.fill"
        case .other: return "ellipsis.circle.fill"
        }
    }
}

enum CashFlowSource: String, Codable, CaseIterable {
    case manual = "Manual"
    case orderPayment = "OrderPayment"
    case orderReversal = "OrderReversal"

    var localizedName: String {
        switch self {
        case .manual: return "Manual"
        case .orderPayment: return "Pedido pago"
        case .orderReversal: return "Estorno"
        }
    }
}

// MARK: - Models

struct CashFlowEntry: Codable, Identifiable {
    let id: String
    let createdAt: Date
    let billingDate: Date
    let type: CashFlowEntryType
    let category: CashFlowCategory
    let counterparty: String
    let amountCents: Int
    let notes: String?
    let source: CashFlowSource
    let sourceId: String?
    let authorUserId: String
    let authorUserName: String
    let updatedAt: Date?
    let deletedAt: Date?
}

struct CashFlowEntriesResponse: Decodable {
    let items: [CashFlowEntry]
    let totalCount: Int
    let pageNumber: Int
    let pageSize: Int
}

struct CashFlowSummary: Decodable {
    let totalInflowCents: Int
    let totalOutflowCents: Int
    let netBalanceCents: Int
    let totalCount: Int
    let inflowByCategory: [String: Int]
    let outflowByCategory: [String: Int]
}

// MARK: - Inputs

struct CreateCashFlowEntryInput: Codable {
    let billingDate: String
    let type: String
    let category: String
    let counterparty: String
    let amountCents: Int
    let notes: String?
}

struct DeleteCashFlowEntryInput: Codable {
    let reason: String
}

// MARK: - Filters

struct CashFlowFilters {
    var from: Date?
    var to: Date?
    var type: CashFlowEntryType?
    var category: CashFlowCategory?
    var source: CashFlowSource?
    var includeDeleted: Bool = false
    var page: Int = 1
    var size: Int = 50

    func queryString() -> String {
        var params: [String] = []
        if let from = from { params.append("from=\(Formatters.utcISOForStartOfLocalDay(from))") }
        if let to = to { params.append("to=\(Formatters.utcISOForExclusiveEndOfLocalDay(to))") }
        if let type = type { params.append("type=\(type.rawValue)") }
        if let category = category { params.append("category=\(category.rawValue)") }
        if let source = source { params.append("source=\(source.rawValue)") }
        if includeDeleted { params.append("includeDeleted=true") }
        params.append("page=\(page)")
        params.append("size=\(size)")

        return params.isEmpty ? "" : "?\(params.joined(separator: "&"))"
    }
}

// MARK: - Chart Data

struct CashChartDataPoint: Identifiable {
    let id = UUID()
    let date: Date
    let label: String
    let inflowCents: Int
    let outflowCents: Int
}
