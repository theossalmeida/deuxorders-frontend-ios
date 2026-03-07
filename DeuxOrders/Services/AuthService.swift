//
//  AuthService.swift
//  DeuxOrders
//
//  Created by Theo on 04/03/26.
//

import Foundation

class AuthService {
    
    private let baseURL = "https://api-orders.deuxcerie.com.br/api/v1/auth"

    func login(credentials: UserCredentials) async throws -> String {
        guard let url = URL(string: "\(baseURL)/login") else {
            throw NetworkError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(credentials)
        request.timeoutInterval = 20

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.noData
        }

        switch httpResponse.statusCode {
        case 200:
            let decoded = try JSONDecoder().decode(LoginResponse.self, from: data)
            return decoded.token
        case 401:
            throw NetworkError.unauthorized
        case 400:
            throw NetworkError.unauthorized
        default:
            throw NetworkError.serverError("Servidor retornou erro \(httpResponse.statusCode)")
        }
    }
}
