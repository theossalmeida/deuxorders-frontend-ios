import Foundation

class DashboardService {
    private let api = APIClient.shared
    private let isoFormatter = APIClient.isoWithoutFractional

    func fetchSummary(start: Date, end: Date) async throws -> DashboardSummary {
        try await api.get(buildEndpoint("dashboard/summary", start: start, end: end), decoder: JSONDecoder())
    }

    func fetchRevenueOverTime(start: Date, end: Date) async throws -> [RevenueDataPoint] {
        let response: RevenueOverTimeResponse = try await api.get(buildEndpoint("dashboard/revenue-over-time", start: start, end: end), decoder: JSONDecoder())
        return response.dataPoints
    }

    func fetchTopProducts(start: Date, end: Date) async throws -> [TopProduct] {
        try await api.get(buildEndpoint("dashboard/top-products", start: start, end: end, extra: ["limit": "5"]), decoder: JSONDecoder())
    }

    func fetchTopClients(start: Date, end: Date) async throws -> [TopClient] {
        try await api.get(buildEndpoint("dashboard/top-clients", start: start, end: end, extra: ["limit": "5"]), decoder: JSONDecoder())
    }

    func exportOrders(from: Date, to: Date, status: OrderStatus?, format: String) async throws -> (Data, String) {
        let endOfDay = Calendar.current.date(bySettingHour: 23, minute: 59, second: 59, of: to) ?? to
        var params = [
            "from=\(isoFormatter.string(from: from))",
            "to=\(isoFormatter.string(from: endOfDay))",
            "format=\(format)"
        ]
        if let status { params.append("status=\(status.rawValue)") }
        let qs = "?\(params.joined(separator: "&"))"

        let data = try await api.download("dashboard/export" + qs)

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyyMMdd"
        let filename = "pedidos_\(dateFormatter.string(from: Date())).\(format)"
        return (data, filename)
    }

    private func buildEndpoint(_ path: String, start: Date, end: Date, extra: [String: String] = [:]) -> String {
        let endOfDay = Calendar.current.date(bySettingHour: 23, minute: 59, second: 59, of: end) ?? end
        var params = [
            "createdAtFrom=\(isoFormatter.string(from: start))",
            "createdAtTo=\(isoFormatter.string(from: endOfDay))"
        ]
        extra.forEach { params.append("\($0.key)=\($0.value)") }
        return path + "?\(params.joined(separator: "&"))"
    }
}
