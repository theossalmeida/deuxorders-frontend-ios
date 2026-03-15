
import Foundation

class DashboardService {
    private let baseURL = "https://api-orders.deuxcerie.com.br/api/v1/dashboard"

    private var token: String? {
        KeychainService.load(forKey: "user_token")
    }

    private let isoFormatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()

    func fetchSummary(start: Date, end: Date) async throws -> DashboardSummary {
        let url = buildURL("summary", start: start, end: end)
        return try await fetchData(url: url, as: DashboardSummary.self)
    }

    func fetchRevenueOverTime(start: Date, end: Date) async throws -> [RevenueDataPoint] {
        let url = buildURL("revenue-over-time", start: start, end: end)
        let response = try await fetchData(url: url, as: RevenueOverTimeResponse.self)
        return response.dataPoints
    }

    func fetchTopProducts(start: Date, end: Date) async throws -> [TopProduct] {
        let url = buildURL("top-products", start: start, end: end, extra: ["limit": "5"])
        return try await fetchData(url: url, as: [TopProduct].self)
    }

    func fetchTopClients(start: Date, end: Date) async throws -> [TopClient] {
        let url = buildURL("top-clients", start: start, end: end, extra: ["limit": "5"])
        return try await fetchData(url: url, as: [TopClient].self)
    }

    func exportOrders(from: Date, to: Date, status: OrderStatus?, format: String) async throws -> (Data, String) {
        guard let token = token else { throw NetworkError.unauthorized }

        var components = URLComponents(string: "\(baseURL)/export")!
        let endOfDay = Calendar.current.date(bySettingHour: 23, minute: 59, second: 59, of: to) ?? to
        var items: [URLQueryItem] = [
            URLQueryItem(name: "startDate", value: isoFormatter.string(from: from)),
            URLQueryItem(name: "endDate", value: isoFormatter.string(from: endOfDay)),
            URLQueryItem(name: "format", value: format)
        ]
        if let status = status {
            items.append(URLQueryItem(name: "status", value: status.rawValue))
        }
        components.queryItems = items

        var request = URLRequest(url: components.url!)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await URLSession.shared.data(for: request)
        try validate(response: response)

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyyMMdd"
        let filename = "pedidos_\(dateFormatter.string(from: Date())).\(format)"
        return (data, filename)
    }

    private func buildURL(_ endpoint: String, start: Date, end: Date, extra: [String: String] = [:]) -> URL {
        var components = URLComponents(string: "\(baseURL)/\(endpoint)")!
        let endOfDay = Calendar.current.date(bySettingHour: 23, minute: 59, second: 59, of: end) ?? end
        var items = [
            URLQueryItem(name: "startDate", value: isoFormatter.string(from: start)),
            URLQueryItem(name: "endDate", value: isoFormatter.string(from: endOfDay))
        ]
        extra.forEach { items.append(URLQueryItem(name: $0.key, value: $0.value)) }
        components.queryItems = items
        return components.url!
    }

    private func fetchData<T: Codable>(url: URL, as type: T.Type) async throws -> T {
        guard let token = token else { throw NetworkError.unauthorized }
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        let (data, response) = try await URLSession.shared.data(for: request)
        try validate(response: response)
        return try JSONDecoder().decode(T.self, from: data)
    }

    private func validate(response: URLResponse) throws {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.serverError("Resposta inválida do servidor")
        }
        if httpResponse.statusCode == 401 {
            KeychainService.delete(forKey: "user_token")
            NotificationCenter.default.post(name: .sessionExpired, object: nil)
            throw NetworkError.unauthorized
        }
        guard (200...299).contains(httpResponse.statusCode) else {
            throw NetworkError.serverError("Falha na API com status: \(httpResponse.statusCode)")
        }
    }
}
