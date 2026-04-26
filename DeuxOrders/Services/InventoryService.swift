import Foundation

class InventoryService {
    private let api = APIClient.shared

    func fetchMaterials(search: String? = nil, status: Bool? = nil) async throws -> [Material] {
        let endpoint = makeEndpoint(
            path: "inventory/all",
            queryItems: [
                URLQueryItem(name: "search", value: search?.nilIfBlank),
                URLQueryItem(name: "status", value: status.map(String.init)),
                URLQueryItem(name: "page", value: "1"),
                URLQueryItem(name: "size", value: "100")
            ]
        )
        let response: MaterialsResponse = try await api.get(endpoint)
        return response.items
    }

    func fetchDropdown() async throws -> [MaterialDropdownItem] {
        try await api.get("inventory/dropdown?status=true")
    }

    func createMaterial(input: CreateMaterialInput) async throws {
        try await api.post("inventory/new", body: input)
    }

    func updateMaterial(id: String, input: UpdateMaterialInput) async throws {
        try await api.put("inventory/\(id)", body: input)
    }

    func restockMaterial(id: String, input: RestockInput) async throws {
        try await api.post("inventory/\(id)/restock", body: input)
    }

    func activateMaterial(id: String) async throws {
        try await api.patch("inventory/\(id)/active")
    }

    func deactivateMaterial(id: String) async throws {
        try await api.patch("inventory/\(id)/inactive")
    }

    private func makeEndpoint(path: String, queryItems: [URLQueryItem]) -> String {
        var components = URLComponents()
        components.path = path
        components.queryItems = queryItems.filter { $0.value != nil }

        return components.url?.absoluteString ?? path
    }
}

private extension String {
    var nilIfBlank: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
