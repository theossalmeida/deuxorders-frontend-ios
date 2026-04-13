//
//  ProductService.swift
//  DeuxOrders
//
//  Created by Theo on 11/03/26.
//

import Foundation

class ProductService {
    private let baseURL = "https://api-orders.deuxcerie.com.br/api/v1/"

    private var token: String? {
        KeychainService.load(forKey: "user_token")
    }

    func fetchProducts() async throws -> [ProductResponse] {
        let request = try makeRequest(endpoint: "products/all", method: "GET")
        let (data, response) = try await URLSession.shared.data(for: request)
        try validate(response: response)
        struct ProductsResponse: Decodable { let items: [ProductResponse] }
        return try JSONDecoder().decode(ProductsResponse.self, from: data).items
    }

    func createProduct(name: String, descricao: String?, price: Double, category: String? = nil, size: String? = nil, imageData: Data? = nil, imageContentType: String? = nil) async throws {
        let boundary = UUID().uuidString
        var request = try makeRequest(endpoint: "products/new", method: "POST")
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.httpBody = buildMultipartBody(name: name, descricao: descricao, price: price, category: category, size: size, imageData: imageData, imageContentType: imageContentType, boundary: boundary)
        let (_, response) = try await URLSession.shared.data(for: request)
        try validate(response: response)
    }

    func updateProduct(id: String, name: String, descricao: String?, price: Double, category: String? = nil, size: String? = nil, imageData: Data? = nil, imageContentType: String? = nil) async throws {
        let boundary = UUID().uuidString
        var request = try makeRequest(endpoint: "products/\(id)", method: "PUT")
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.httpBody = buildMultipartBody(name: name, descricao: descricao, price: price, category: category, size: size, imageData: imageData, imageContentType: imageContentType, boundary: boundary)
        let (_, response) = try await URLSession.shared.data(for: request)
        try validate(response: response)
    }

    func deleteProduct(id: String) async throws {
        let request = try makeRequest(endpoint: "products/\(id)", method: "DELETE")
        let (_, response) = try await URLSession.shared.data(for: request)
        try validate(response: response)
    }

    func deactivateProduct(id: String) async throws {
        var request = try makeRequest(endpoint: "products/\(id)/inactive", method: "PATCH")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let (_, response) = try await URLSession.shared.data(for: request)
        try validate(response: response)
    }

    func deleteProductImage(id: String) async throws {
        let request = try makeRequest(endpoint: "products/\(id)/image", method: "DELETE")
        let (_, response) = try await URLSession.shared.data(for: request)
        try validate(response: response)
    }

    func activateProduct(id: String) async throws {
        var request = try makeRequest(endpoint: "products/\(id)/active", method: "PATCH")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let (_, response) = try await URLSession.shared.data(for: request)
        try validate(response: response)
    }

    // MARK: - Private Helpers

    private func buildMultipartBody(name: String, descricao: String?, price: Double, category: String?, size: String?, imageData: Data?, imageContentType: String?, boundary: String) -> Data {
        var body = Data()
        let priceInCents = String(Int(price))

        func appendField(_ name: String, value: String) {
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"\(name)\"\r\n\r\n".data(using: .utf8)!)
            body.append("\(value)\r\n".data(using: .utf8)!)
        }

        appendField("name", value: name)
        appendField("price", value: priceInCents)
        if let descricao {
            appendField("descricao", value: descricao)
        }
        if let category {
            appendField("category", value: category)
        }
        if let size {
            appendField("size", value: size)
        }

        if let imageData, let contentType = imageContentType {
            let ext = contentType.contains("png") ? "png" : "jpg"
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"image\"; filename=\"product.\(ext)\"\r\n".data(using: .utf8)!)
            body.append("Content-Type: \(contentType)\r\n\r\n".data(using: .utf8)!)
            body.append(imageData)
            body.append("\r\n".data(using: .utf8)!)
        }

        body.append("--\(boundary)--\r\n".data(using: .utf8)!)
        return body
    }

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
