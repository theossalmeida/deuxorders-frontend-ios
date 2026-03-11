//
//  OrderService.swift
//  DeuxOrders
//
//  Created by Theo on 04/03/26.
//


import Foundation

struct QuantityUpdateInput: Codable {
    let increment: Int
}

class OrderService {
    private let baseURL = "https://api-orders.deuxcerie.com.br/api/v1/"
    
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
        UserDefaults.standard.string(forKey: "user_token")
    }

    func fetchOrders() async throws -> [Order] {
        let url = URL(string: baseURL + "orders/all?size=100")!
        let response = try await fetchData(url: url, responseType: OrderResponse.self)
        return response.items.sorted { $0.deliveryDate > $1.deliveryDate }
    }
    
    func createOrder(input: OrderInput) async throws {
        try await performRequestWithBody(endpoint: "orders/new", method: "POST", input: input)
    }
    
    func updateOrder(id: String, input: OrderInput) async throws {
        try await performRequestWithBody(endpoint: "orders/\(id)", method: "PUT", input: input)
    }

    func completeOrder(id: String) async throws {
        try await performPatch(endpoint: "orders/\(id)/complete")
    }
    
    func cancelOrder(id: String) async throws {
        try await performPatch(endpoint: "orders/\(id)/cancel")
    }
    
    func cancelOrderItem(orderId: String, productId: String) async throws {
        try await performPatch(endpoint: "order/\(orderId)/items/\(productId)/cancel")
    }

    func updateOrderItemQuantity(orderId: String, productId: String, increment: Int) async throws {
        let input = QuantityUpdateInput(increment: increment)
        try await performRequestWithBody(endpoint: "order/\(orderId)/items/\(productId)/quantity", method: "PATCH", input: input)
    }
    
    func deleteOrder(id: String) async throws {
        guard let url = URL(string: baseURL + "orders/\(id)") else { throw NetworkError.invalidURL }
        guard let token = token else { throw NetworkError.unauthorized }
        
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        let (_, response) = try await URLSession.shared.data(for: request)
        try validate(response: response)
    }
    
    func fetchClients() async throws -> [Client] {
        let url = URL(string: baseURL + "clients/dropdown?status=true")!
        return try await fetchData(url: url, responseType: [Client].self)
    }

    func fetchProducts() async throws -> [ProductResponse] {
        let url = URL(string: baseURL + "products/dropdown?status=true")!
        return try await fetchData(url: url, responseType: [ProductResponse].self)
    }
    
    private func performRequestWithBody<T: Codable>(endpoint: String, method: String, input: T) async throws {
        guard let url = URL(string: baseURL + endpoint) else { throw NetworkError.invalidURL }
        guard let token = token else { throw NetworkError.unauthorized }
        
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONEncoder().encode(input)
        
        let (_, response) = try await URLSession.shared.data(for: request)
        try validate(response: response)
    }
    
    private func performPatch(endpoint: String) async throws {
        guard let url = URL(string: baseURL + endpoint) else { throw NetworkError.invalidURL }
        guard let token = token else { throw NetworkError.unauthorized }
        
        var request = URLRequest(url: url)
        request.httpMethod = "PATCH"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let (_, response) = try await URLSession.shared.data(for: request)
        try validate(response: response)
    }
    
    private func fetchData<T: Codable>(url: URL, responseType: T.Type) async throws -> T {
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
        guard (200...299).contains(httpResponse.statusCode) else {
            throw NetworkError.serverError("Falha na API com status: \(httpResponse.statusCode)")
        }
    }
}
