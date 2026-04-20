//
//  CashService.swift
//  DeuxOrders
//

import Foundation

class CashService {
    private let baseURL = "https://deux-erp.deuxcerie.com.br/api/v1/"

    private static let isoFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    private static let fallbackFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()

    private let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let dateString = try container.decode(String.self)

            if let date = isoFormatter.date(from: dateString) { return date }
            if let date = fallbackFormatter.date(from: dateString) { return date }
            return Date()
        }
        return decoder
    }()

    private var token: String? {
        KeychainService.load(forKey: "user_token")
    }

    // MARK: - Public API

    func fetchEntries(filters: CashFlowFilters) async throws -> CashFlowEntriesResponse {
        let url = URL(string: baseURL + "cash/entries" + filters.queryString())!
        return try await fetchData(url: url, responseType: CashFlowEntriesResponse.self)
    }

    func fetchEntry(id: String) async throws -> CashFlowEntry {
        let url = URL(string: baseURL + "cash/entries/\(id)")!
        return try await fetchData(url: url, responseType: CashFlowEntry.self)
    }

    func createEntry(input: CreateCashFlowEntryInput) async throws {
        var request = try makeRequest(endpoint: "cash/entries", method: "POST")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(input)

        let (_, response) = try await URLSession.shared.data(for: request)
        try validate(response: response)
    }

    func updateEntry(id: String, input: CreateCashFlowEntryInput) async throws {
        var request = try makeRequest(endpoint: "cash/entries/\(id)", method: "PUT")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(input)

        let (_, response) = try await URLSession.shared.data(for: request)
        try validate(response: response)
    }

    func deleteEntry(id: String, reason: String) async throws {
        var request = try makeRequest(endpoint: "cash/entries/\(id)", method: "DELETE")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(DeleteCashFlowEntryInput(reason: reason))

        let (_, response) = try await URLSession.shared.data(for: request)
        try validate(response: response)
    }

    func fetchSummary(from: Date?, to: Date?) async throws -> CashFlowSummary {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]

        var params: [String] = []
        if let from = from { params.append("from=\(formatter.string(from: from))") }
        if let to = to { params.append("to=\(formatter.string(from: to))") }
        let qs = params.isEmpty ? "" : "?\(params.joined(separator: "&"))"

        let url = URL(string: baseURL + "cash/summary" + qs)!
        return try await fetchData(url: url, responseType: CashFlowSummary.self)
    }

    // MARK: - Private Helpers

    private func makeRequest(endpoint: String, method: String) throws -> URLRequest {
        guard let url = URL(string: baseURL + endpoint) else { throw NetworkError.invalidURL }
        guard let token = token else { throw NetworkError.unauthorized }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        return request
    }

    private func fetchData<T: Decodable>(url: URL, responseType: T.Type) async throws -> T {
        guard let token = token else { throw NetworkError.unauthorized }

        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await URLSession.shared.data(for: request)
        try validate(response: response)
        return try decoder.decode(T.self, from: data)
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
