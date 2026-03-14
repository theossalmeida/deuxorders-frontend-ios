import Foundation

struct DashboardSummary: Codable {
    let totalRevenue: Int
    let totalValue: Int
    let totalDiscount: Int
    let totalOrders: Int
    let pendingOrders: Int
    let completedOrders: Int
    let canceledOrders: Int
    let averageRevenuePerOrder: Int
}

struct RevenueDataPoint: Codable, Identifiable {
    let date: String
    let revenue: Int
    let orderCount: Int

    var id: String { date }

    var parsedDate: Date {
        RevenueDataPoint.dateFormatter.date(from: date) ?? Date()
    }

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()
}

struct RevenueOverTimeResponse: Codable {
    let dataPoints: [RevenueDataPoint]
}

struct TopProduct: Codable, Identifiable {
    let productId: String
    let productName: String
    let totalRevenue: Int
    let totalQuantitySold: Int
    let orderCount: Int

    var id: String { productId }
}

struct TopClient: Codable, Identifiable {
    let clientId: String
    let clientName: String
    let totalRevenue: Int
    let orderCount: Int

    var id: String { clientId }
}
