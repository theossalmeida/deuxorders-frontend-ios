import Foundation

class AuthService {
    private let api = APIClient.shared

    func login(credentials: UserCredentials) async throws -> String {
        let bodyData = try JSONEncoder().encode(credentials)
        let (data, _) = try await api.request(
            endpoint: "auth/login",
            method: "POST",
            body: bodyData,
            authenticated: false
        )
        let decoded = try JSONDecoder().decode(LoginResponse.self, from: data)
        return decoded.token
    }
}
