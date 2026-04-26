import Foundation
import Combine

@MainActor
class DashboardViewModel: ObservableObject {
    @Published var summary: DashboardSummary?
    @Published var revenueOverTime: [RevenueDataPoint] = []
    @Published var topProducts: [TopProduct] = []
    @Published var topClients: [TopClient] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    @Published var selectedPreset: DateRangePreset = .month
    @Published var startDate: Date
    @Published var endDate: Date

    private let service = DashboardService()

    init() {
        let (start, end) = DateRangePreset.month.dates()!
        self.startDate = start
        self.endDate = end
    }

    func selectPreset(_ preset: DateRangePreset) {
        selectedPreset = preset
        if let (start, end) = preset.dates() {
            startDate = start
            endDate = end
            Task { await loadAll() }
        }
    }

    @Published var isExporting = false
    @Published var exportError: String?
    @Published var exportedFileURL: URL?

    func exportOrders(format: String) async {
        isExporting = true
        defer { isExporting = false }
        do {
            let (data, filename) = try await service.exportOrders(from: startDate, to: endDate, status: nil, format: format)
            let url = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
            try data.write(to: url, options: .atomic)
            exportedFileURL = url
        } catch {
            exportError = "Falha ao exportar. Tente novamente."
        }
    }

    func loadAll() async {
        isLoading = true
        defer { isLoading = false }
        do {
            async let s = service.fetchSummary(start: startDate, end: endDate)
            async let r = service.fetchRevenueOverTime(start: startDate, end: endDate)
            async let p = service.fetchTopProducts(start: startDate, end: endDate)
            async let c = service.fetchTopClients(start: startDate, end: endDate)
            (summary, revenueOverTime, topProducts, topClients) = try await (s, r, p, c)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
