import Foundation

class ClientService {
    private let api = APIClient.shared

    func fetchClients() async throws -> [Client] {
        struct ClientsResponse: Decodable { let items: [Client] }
        let response: ClientsResponse = try await api.get("clients/all?size=100")
        return response.items
    }

    func createClient(input: ClientInput) async throws {
        try await api.post("clients/new", body: input)
    }

    func deleteClient(id: String) async throws {
        try await api.delete("clients/\(id)")
    }

    func deactivateClient(id: String) async throws {
        try await api.patch("clients/\(id)/inactive")
    }

    func updateClient(id: String, input: ClientInput) async throws {
        try await api.put("clients/\(id)", body: input)
    }

    func fetchClientDetail(id: String) async throws -> ClientDetail {
        try await api.get("clients/\(id)?orders=true")
    }

    func activateClient(id: String) async throws {
        try await api.patch("clients/\(id)/active")
    }
}
