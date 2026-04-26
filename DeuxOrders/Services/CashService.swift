import Foundation

class CashService {
    private let api = APIClient.shared

    func fetchEntries(filters: CashFlowFilters) async throws -> CashFlowEntriesResponse {
        try await api.get("cash/entries" + filters.queryString())
    }

    func fetchEntry(id: String) async throws -> CashFlowEntry {
        try await api.get("cash/entries/\(id)")
    }

    func createEntry(input: CreateCashFlowEntryInput) async throws {
        try await api.post("cash/entries", body: input)
    }

    func updateEntry(id: String, input: CreateCashFlowEntryInput) async throws {
        try await api.put("cash/entries/\(id)", body: input)
    }

    func deleteEntry(id: String, reason: String) async throws {
        try await api.delete("cash/entries/\(id)", body: DeleteCashFlowEntryInput(reason: reason))
    }

    func fetchSummary(from: Date?, to: Date?) async throws -> CashFlowSummary {
        let formatter = APIClient.isoWithoutFractional
        var params: [String] = []
        if let from { params.append("from=\(formatter.string(from: from))") }
        if let to { params.append("to=\(formatter.string(from: to))") }
        let qs = params.isEmpty ? "" : "?\(params.joined(separator: "&"))"
        return try await api.get("cash/summary" + qs)
    }
}
