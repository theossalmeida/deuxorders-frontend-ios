//
//  ClientService.swift
//  DeuxOrders
//
//  Created by Theo on 11/03/26.
//

import Foundation

class ClientService {
    private let baseURL = "https://api-orders.deuxcerie.com.br/api/v1/"
    
    private var token: String? {
        UserDefaults.standard.string(forKey: "user_token")
    }
    
    func fetchClients() async throws -> [Client] {
        let request = try makeRequest(endpoint: "clients/all", method: "GET")
        let (data, response) = try await URLSession.shared.data(for: request)
        try validate(response: response)
        
        return try JSONDecoder().decode([Client].self, from: data)
    }
    
    func createClient(input: ClientInput) async throws {
        // Assuming the endpoint follows the "orders/new" pattern. Adjust if necessary.
        var request = try makeRequest(endpoint: "clients/new", method: "POST")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(input)
        
        let (_, response) = try await URLSession.shared.data(for: request)
        try validate(response: response)
    }
    
    func deleteClient(id: String) async throws {
        let request = try makeRequest(endpoint: "clients/\(id)", method: "DELETE")
        let (_, response) = try await URLSession.shared.data(for: request)
        try validate(response: response)
    }
    
    func deactivateClient(id: String) async throws {
        var request = try makeRequest(endpoint: "clients/\(id)/inactive", method: "PATCH")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let (_, response) = try await URLSession.shared.data(for: request)
        try validate(response: response)
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
    
    private func validate(response: URLResponse) throws {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.serverError("Invalid server response")
        }
        guard (200...299).contains(httpResponse.statusCode) else {
            throw NetworkError.serverError("API failure with status: \(httpResponse.statusCode)")
        }
    }
}
