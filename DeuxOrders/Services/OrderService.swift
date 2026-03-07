//
//  OrderService.swift
//  DeuxOrders
//
//  Created by Theo on 04/03/26.
//

import Foundation

class OrderService {
    private let baseURL = "https://api-orders.deuxcerie.com.br/api/v1/"
    
    // MARK: - Decodificador Customizado
    private var customDecoder: JSONDecoder {
        let decoder = JSONDecoder()
        
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let dateString = try container.decode(String.self)
            
            let formatter = ISO8601DateFormatter()
            
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let date = formatter.date(from: dateString) {
                return date
            }
            
            formatter.formatOptions = [.withInternetDateTime]
            if let date = formatter.date(from: dateString) {
                return date
            }
            
            return Date()
        }
        
        return decoder
    }

    // MARK: - Pedidos (Orders)
    
    func fetchOrders() async throws -> [Order] {
        let url = URL(string: baseURL + "orders/all?size=100")!
        guard let token = UserDefaults.standard.string(forKey: "user_token") else { throw NetworkError.unauthorized }
        
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        let (data, _) = try await URLSession.shared.data(for: request)
        
        let decodedResponse = try customDecoder.decode(OrderResponse.self, from: data)
        
        return decodedResponse.items.sorted { $0.deliveryDate > $1.deliveryDate }
    }
    
    func createOrder(input: OrderInput) async throws {
        let url = URL(string: baseURL + "orders/new")!
        
        guard let token = UserDefaults.standard.string(forKey: "user_token") else { throw NetworkError.unauthorized }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        let encoder = JSONEncoder()
        request.httpBody = try encoder.encode(input)
        
        let (_, response) = try await URLSession.shared.data(for: request)
        
        if let httpResponse = response as? HTTPURLResponse {
            if !(200...299).contains(httpResponse.statusCode) {
                throw NetworkError.serverError("Falha na API: \(httpResponse.statusCode)")
            }
        }
    }

    
    func fetchClients() async throws -> [Client] {
        let url = URL(string: baseURL + "clients/all")!
        return try await fetchData(url: url, responseType: [Client].self)
    }

    func fetchProducts() async throws -> [ProductResponse] {
        let url = URL(string: baseURL + "products/all")!
        return try await fetchData(url: url, responseType: [ProductResponse].self)
    }

    
    private func fetchData<T: Codable>(url: URL, responseType: T.Type) async throws -> T {
        guard let token = UserDefaults.standard.string(forKey: "user_token") else { throw NetworkError.unauthorized }
        
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        if let httpResponse = response as? HTTPURLResponse, !(200...299).contains(httpResponse.statusCode) {
            throw NetworkError.serverError("Erro na requisição")
        }
        
        do {
            return try customDecoder.decode(T.self, from: data)
        } catch {
            throw error
        }
    }
}
