import Foundation

enum APIError: Error, LocalizedError {
    case invalidURL
    case unauthorized
    case validation(String)
    case server(status: Int, message: String?)
    case decoding(Error)
    case network(URLError)

    var errorDescription: String? {
        switch self {
        case .invalidURL: return "URL inválida"
        case .unauthorized: return "Sessão expirada. Faça login novamente."
        case .validation(let msg): return msg
        case .server(let status, let msg): return msg ?? "Erro do servidor (\(status))"
        case .decoding(let err): return "Erro ao processar resposta: \(err.localizedDescription)"
        case .network(let err): return err.localizedDescription
        }
    }
}

final class APIClient {
    static let shared = APIClient()

    let baseURL: String

    static let dateDecoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let dateString = try container.decode(String.self)
            if let date = isoWithFractional.date(from: dateString) { return date }
            if let date = isoWithoutFractional.date(from: dateString) { return date }
            #if DEBUG
            print("[APIClient] Failed to parse date: \(dateString)")
            #endif
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Cannot decode date: \(dateString)")
        }
        return decoder
    }()

    static let isoWithFractional: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    static let isoWithoutFractional: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()

    private init() {
        self.baseURL = AppEnvironment.baseURL
    }

    private var token: String? {
        KeychainService.load(forKey: AppEnvironment.tokenKey)
    }

    // MARK: - Core Request Methods

    func request(
        endpoint: String,
        method: String,
        body: Data? = nil,
        contentType: String = "application/json",
        authenticated: Bool = true
    ) async throws -> (Data, HTTPURLResponse) {
        guard let url = URL(string: baseURL + endpoint) else {
            throw APIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.httpBody = body

        if body != nil {
            request.setValue(contentType, forHTTPHeaderField: "Content-Type")
        }

        if authenticated {
            guard let token = token else { throw APIError.unauthorized }
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch let error as URLError {
            throw APIError.network(error)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.server(status: 0, message: "Resposta inválida do servidor")
        }

        if httpResponse.statusCode == 401 {
            KeychainService.delete(forKey: AppEnvironment.tokenKey)
            NotificationCenter.default.post(name: .sessionExpired, object: nil)
            throw APIError.unauthorized
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            let message = String(data: data, encoding: .utf8)
            throw APIError.server(status: httpResponse.statusCode, message: message)
        }

        return (data, httpResponse)
    }

    // MARK: - Convenience Methods

    func get<T: Decodable>(_ endpoint: String, decoder: JSONDecoder? = nil) async throws -> T {
        let (data, _) = try await request(endpoint: endpoint, method: "GET")
        do {
            return try (decoder ?? Self.dateDecoder).decode(T.self, from: data)
        } catch let error as DecodingError {
            #if DEBUG
            print("[APIClient] Decoding error for \(endpoint): \(error)")
            if let json = String(data: data, encoding: .utf8) {
                print("[APIClient] Raw response: \(json.prefix(500))")
            }
            #endif
            throw APIError.decoding(error)
        }
    }

    func post<I: Encodable>(_ endpoint: String, body: I) async throws {
        let bodyData = try JSONEncoder().encode(body)
        _ = try await request(endpoint: endpoint, method: "POST", body: bodyData)
    }

    func post<I: Encodable, O: Decodable>(_ endpoint: String, body: I, decoder: JSONDecoder? = nil) async throws -> O {
        let bodyData = try JSONEncoder().encode(body)
        let (data, _) = try await request(endpoint: endpoint, method: "POST", body: bodyData)
        return try (decoder ?? Self.dateDecoder).decode(O.self, from: data)
    }

    func put<I: Encodable>(_ endpoint: String, body: I) async throws {
        let bodyData = try JSONEncoder().encode(body)
        _ = try await request(endpoint: endpoint, method: "PUT", body: bodyData)
    }

    func put<I: Encodable, O: Decodable>(_ endpoint: String, body: I, decoder: JSONDecoder? = nil) async throws -> O {
        let bodyData = try JSONEncoder().encode(body)
        let (data, _) = try await request(endpoint: endpoint, method: "PUT", body: bodyData)
        return try (decoder ?? Self.dateDecoder).decode(O.self, from: data)
    }

    func patch(_ endpoint: String) async throws {
        _ = try await request(endpoint: endpoint, method: "PATCH")
    }

    func patch<I: Encodable>(_ endpoint: String, body: I) async throws {
        let bodyData = try JSONEncoder().encode(body)
        _ = try await request(endpoint: endpoint, method: "PATCH", body: bodyData)
    }

    func delete(_ endpoint: String) async throws {
        _ = try await request(endpoint: endpoint, method: "DELETE")
    }

    func delete<I: Encodable>(_ endpoint: String, body: I) async throws {
        let bodyData = try JSONEncoder().encode(body)
        _ = try await request(endpoint: endpoint, method: "DELETE", body: bodyData)
    }

    // MARK: - Multipart Upload

    func multipart(
        endpoint: String,
        method: String = "POST",
        fields: [(String, String)],
        fileField: String? = nil,
        fileName: String? = nil,
        fileData: Data? = nil,
        fileContentType: String? = nil
    ) async throws {
        let boundary = UUID().uuidString
        var body = Data()

        for (name, value) in fields {
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"\(name)\"\r\n\r\n".data(using: .utf8)!)
            body.append("\(value)\r\n".data(using: .utf8)!)
        }

        if let fileField, let fileName, let fileData, let fileContentType {
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"\(fileField)\"; filename=\"\(fileName)\"\r\n".data(using: .utf8)!)
            body.append("Content-Type: \(fileContentType)\r\n\r\n".data(using: .utf8)!)
            body.append(fileData)
            body.append("\r\n".data(using: .utf8)!)
        }

        body.append("--\(boundary)--\r\n".data(using: .utf8)!)

        _ = try await request(
            endpoint: endpoint,
            method: method,
            body: body,
            contentType: "multipart/form-data; boundary=\(boundary)"
        )
    }

    // MARK: - Raw Upload (presigned URLs, no auth)

    func uploadRaw(to urlString: String, data: Data, contentType: String) async throws {
        guard let url = URL(string: urlString) else { throw APIError.invalidURL }
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue(contentType, forHTTPHeaderField: "Content-Type")
        request.httpBody = data

        let (_, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw APIError.server(status: 0, message: "Falha ao enviar arquivo")
        }
    }

    // MARK: - Download

    func download(_ endpoint: String) async throws -> Data {
        let (data, _) = try await request(endpoint: endpoint, method: "GET")
        return data
    }
}
