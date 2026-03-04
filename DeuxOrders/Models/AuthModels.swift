//
//  AuthModels.swift
//  DeuxOrders
//
//  Created by Theo on 04/03/26.
//

import Foundation

// Gestão de erros robusta para exibição em Alerts ou Texts
enum NetworkError: Error, LocalizedError {
    case invalidURL
    case noData
    case unauthorized
    case serverError(String)
    
    var errorDescription: String? {
        switch self {
        case .unauthorized: return "Email ou senha incorretos."
        case .serverError(let msg): return msg
        case .invalidURL: return "Erro interno na URL de conexão."
        case .noData: return "Não foi possível receber dados do servidor."
        }
    }
}

// DTOs que espelham o seu backend C#
struct UserCredentials: Codable {
    let email: String
    let password: String
}

struct LoginResponse: Codable {
    let token: String
}
