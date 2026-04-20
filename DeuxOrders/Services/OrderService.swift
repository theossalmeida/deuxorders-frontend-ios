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

struct DeleteReferenceRequest: Codable {
    let objectKey: String
}

struct UnpayRequest: Codable {
    let reason: String
}

struct PresignedUploadRequest: Codable {
    let fileName: String
    let contentType: String
}

struct PresignedUploadResponse: Codable {
    let uploadUrl: String
    let objectKey: String
}

class OrderService {
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

    func fetchOrders() async throws -> [Order] {
        let url = URL(string: baseURL + "orders/all?page=1&size=100")!
        let response = try await fetchData(url: url, responseType: OrderResponse.self)
        return response.items.sorted { $0.deliveryDate > $1.deliveryDate }
    }
    
    func createOrder(input: OrderInput) async throws {
        try await performRequestWithBody(endpoint: "orders/new", method: "POST", input: input)
    }
    
    func updateOrder(id: String, input: UpdateOrderRequest) async throws {
        try await performRequestWithBody(endpoint: "orders/\(id)", method: "PUT", input: input)
    }

    func completeOrder(id: String) async throws {
        try await performPatch(endpoint: "orders/\(id)/complete")
    }
    
    func cancelOrder(id: String) async throws {
        try await performPatch(endpoint: "orders/\(id)/cancel")
    }

    func payOrder(id: String) async throws {
        try await performPatch(endpoint: "orders/\(id)/pay")
    }

    func unpayOrder(id: String, reason: String) async throws {
        try await performRequestWithBody(endpoint: "orders/\(id)/unpay", method: "PATCH", input: UnpayRequest(reason: reason))
    }
    
    func cancelOrderItem(orderId: String, productId: String) async throws {
        try await performPatch(endpoint: "orders/\(orderId)/items/\(productId)/cancel")
    }

    func updateOrderItemQuantity(orderId: String, productId: String, increment: Int) async throws {
        let input = QuantityUpdateInput(increment: increment)
        try await performRequestWithBody(endpoint: "orders/\(orderId)/items/\(productId)/quantity", method: "PATCH", input: input)
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
    
    func deleteReference(orderId: String, objectKey: String) async throws {
        guard let url = URL(string: baseURL + "orders/\(orderId)/references") else { throw NetworkError.invalidURL }
        guard let token = token else { throw NetworkError.unauthorized }

        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONEncoder().encode(DeleteReferenceRequest(objectKey: objectKey))

        let (_, response) = try await URLSession.shared.data(for: request)
        try validate(response: response)
    }

    func getPresignedUrl(fileName: String, contentType: String) async throws -> PresignedUploadResponse {
        let input = PresignedUploadRequest(fileName: fileName, contentType: contentType)
        guard let url = URL(string: baseURL + "orders/references/presigned-url") else { throw NetworkError.invalidURL }
        guard let token = token else { throw NetworkError.unauthorized }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONEncoder().encode(input)

        let (data, response) = try await URLSession.shared.data(for: request)
        try validate(response: response)
        return try JSONDecoder().decode(PresignedUploadResponse.self, from: data)
    }

    func uploadImage(to presignedUrl: String, data: Data, contentType: String) async throws {
        guard let url = URL(string: presignedUrl) else { throw NetworkError.invalidURL }
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue(contentType, forHTTPHeaderField: "Content-Type")
        request.httpBody = data

        let (_, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw NetworkError.serverError("Falha ao enviar imagem para o armazenamento")
        }
    }

    func fetchClients() async throws -> [Client] {
        let url = URL(string: baseURL + "clients/dropdown?status=true")!
        return try await fetchData(url: url, responseType: [Client].self)
    }

    func fetchProducts() async throws -> [ProductResponse] {
        let url = URL(string: baseURL + "products/all?size=100&status=true")!
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
