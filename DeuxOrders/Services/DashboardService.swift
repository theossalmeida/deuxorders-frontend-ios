import Foundation

class DashboardService {
    private let api = APIClient.shared

    func fetchSummary(start: Date, end: Date) async throws -> DashboardSummary {
        try await api.get(buildEndpoint("dashboard/summary", start: start, end: end))
    }

    func fetchRevenueOverTime(start: Date, end: Date) async throws -> [RevenueDataPoint] {
        let response: RevenueOverTimeResponse = try await api.get(buildEndpoint("dashboard/revenue-over-time", start: start, end: end))
        return response.dataPoints
    }

    func fetchTopProducts(start: Date, end: Date) async throws -> [TopProduct] {
        try await api.get(buildEndpoint("dashboard/top-products", start: start, end: end, extra: ["limit": "5"]))
    }

    func fetchTopClients(start: Date, end: Date) async throws -> [TopClient] {
        try await api.get(buildEndpoint("dashboard/top-clients", start: start, end: end, extra: ["limit": "5"]))
    }

    func exportOrders(from: Date, to: Date, status: OrderStatus?, format: String) async throws -> (Data, String) {
        var params = [
            "from=\(Formatters.utcISOForStartOfLocalDay(from))",
            "to=\(Formatters.utcISOForExclusiveEndOfLocalDay(to))",
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
        var params = [
            "createdAtFrom=\(Formatters.utcISOForStartOfLocalDay(start))",
            "createdAtTo=\(Formatters.utcISOForExclusiveEndOfLocalDay(end))"
        ]
        extra.forEach { params.append("\($0.key)=\($0.value)") }
        return path + "?\(params.joined(separator: "&"))"
    }
}
