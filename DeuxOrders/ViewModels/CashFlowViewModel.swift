//
//  CashFlowViewModel.swift
//  DeuxOrders
//

import Foundation
import Combine

@MainActor
class CashFlowViewModel: ObservableObject {
    @Published var entries: [CashFlowEntry] = []
    @Published var summary: CashFlowSummary?
    @Published var isLoading = false
    @Published var errorMessage: String?

    @Published var selectedTypeFilter: CashFlowEntryType?
    @Published var searchText: String = ""

    @Published var selectedPreset: DateRangePreset = .month
    @Published var startDate: Date
    @Published var endDate: Date

    private let service = CashService()

    init() {
        let (start, end) = DateRangePreset.month.dates()!
        self.startDate = start
        self.endDate = end
    }

    // MARK: - Computed

    var filteredEntries: [CashFlowEntry] {
        var result = entries
        if let type = selectedTypeFilter {
            result = result.filter { $0.type == type }
        }
        if !searchText.isEmpty {
            result = result.filter { $0.counterparty.localizedCaseInsensitiveContains(searchText) }
        }
        return result
    }

    var chartData: [CashChartDataPoint] {
        let calendar = Calendar.current
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "pt_BR")
        formatter.dateFormat = "d MMM"

        let grouped = Dictionary(grouping: entries) { entry in
            calendar.startOfDay(for: entry.billingDate)
        }

        return grouped.keys.sorted().map { date in
            let dayEntries = grouped[date]!
            let inflow = dayEntries.filter { $0.type == .inflow }.reduce(0) { $0 + $1.amountCents }
            let outflow = dayEntries.filter { $0.type == .outflow }.reduce(0) { $0 + $1.amountCents }
            return CashChartDataPoint(
                date: date,
                label: formatter.string(from: date),
                inflowCents: inflow,
                outflowCents: outflow
            )
        }
    }

    var categoryBreakdown: [(category: CashFlowCategory, amount: Int)] {
        guard let summary = summary else { return [] }
        return summary.outflowByCategory.compactMap { key, value in
            guard let category = CashFlowCategory(rawValue: key) else { return nil }
            return (category: category, amount: value)
        }.sorted { $0.amount > $1.amount }
    }

    var recentEntries: [CashFlowEntry] {
        Array(entries.prefix(6))
    }

    // MARK: - Date Range

    func selectPreset(_ preset: DateRangePreset) {
        selectedPreset = preset
        if let (start, end) = preset.dates() {
            startDate = start
            endDate = end
            Task { await loadDashboard() }
        }
    }

    // MARK: - Data Loading

    func loadDashboard() async {
        isLoading = true
        defer { isLoading = false }

        do {
            let filters = CashFlowFilters(from: startDate, to: endDate, size: 100)
            async let s = service.fetchSummary(from: startDate, to: endDate)
            async let e = service.fetchEntries(filters: filters)
            let (summaryResult, entriesResult) = try await (s, e)
            self.summary = summaryResult
            self.entries = entriesResult.items
            self.errorMessage = nil
        } catch {
            self.errorMessage = error.localizedDescription
        }
    }

    func loadEntries() async {
        isLoading = true
        defer { isLoading = false }

        do {
            let filters = CashFlowFilters(
                from: startDate,
                to: endDate,
                type: selectedTypeFilter,
                size: 100
            )
            let response = try await service.fetchEntries(filters: filters)
            self.entries = response.items
            self.errorMessage = nil
        } catch {
            self.errorMessage = error.localizedDescription
        }
    }

    // MARK: - CRUD

    func createEntry(input: CreateCashFlowEntryInput) async -> Bool {
        do {
            try await service.createEntry(input: input)
            await loadDashboard()
            return true
        } catch {
            self.errorMessage = "Falha ao criar lançamento."
            return false
        }
    }

    func updateEntry(id: String, input: CreateCashFlowEntryInput) async -> Bool {
        do {
            try await service.updateEntry(id: id, input: input)
            await loadDashboard()
            return true
        } catch {
            self.errorMessage = "Falha ao atualizar lançamento."
            return false
        }
    }

    func deleteEntry(id: String, reason: String) async {
        let backup = entries
        entries.removeAll { $0.id == id }

        do {
            try await service.deleteEntry(id: id, reason: reason)
            await loadDashboard()
        } catch {
            entries = backup
            self.errorMessage = "Falha ao excluir lançamento."
        }
    }
}
