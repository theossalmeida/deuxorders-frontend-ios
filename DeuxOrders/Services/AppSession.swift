import Foundation

enum AppSession {
    static func logout() {
        KeychainService.delete(forKey: AppEnvironment.tokenKey)
        NotificationCenter.default.post(name: .sessionExpired, object: nil)
    }

    static var isAdministrator: Bool {
        guard let token = KeychainService.load(forKey: AppEnvironment.tokenKey),
              let payload = decodeJWTPayload(token) else {
            return false
        }

        let roleKeys = [
            "role",
            "roles",
            "http://schemas.microsoft.com/ws/2008/06/identity/claims/role"
        ]

        return roleKeys.contains { key in
            guard let value = payload[key] else { return false }
            if let role = value as? String {
                return isAdminRole(role)
            }
            if let roles = value as? [String] {
                return roles.contains { isAdminRole($0) }
            }
            return false
        }
    }

    private static func isAdminRole(_ role: String) -> Bool {
        let normalized = role.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return normalized == "administrator" || normalized == "admin"
    }

    private static func decodeJWTPayload(_ token: String) -> [String: Any]? {
        let parts = token.split(separator: ".")
        guard parts.count >= 2 else { return nil }

        var base64 = String(parts[1])
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")

        while base64.count % 4 != 0 {
            base64.append("=")
        }

        guard let data = Data(base64Encoded: base64),
              let object = try? JSONSerialization.jsonObject(with: data),
              let payload = object as? [String: Any] else {
            return nil
        }

        return payload
    }
}
