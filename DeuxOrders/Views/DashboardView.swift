import SwiftUI
import Charts

struct DashboardView: View {
    @ObservedObject var viewModel: DashboardViewModel
    @State private var showExportOptions = false

    private let brandColor = Color(red: 88/255, green: 22/255, blue: 41/255)

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    dateFilterSection

                    if viewModel.isLoading {
                        ProgressView("Carregando...")
                            .frame(maxWidth: .infinity)
                            .padding(.top, 60)
                    } else if let error = viewModel.errorMessage {
                        Text(error)
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity)
                            .padding(.top, 60)
                    } else if let summary = viewModel.summary {
                        summarySection(summary)
                        statusSection(summary)
                        if !viewModel.revenueOverTime.isEmpty {
                            revenueChartSection
                        }
                        if !viewModel.topProducts.isEmpty {
                            topProductsSection
                        }
                        if !viewModel.topClients.isEmpty {
                            topClientsSection
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("Dashboard")
            .task { await viewModel.loadAll() }
            .sheet(isPresented: Binding(
                get: { viewModel.exportedFileURL != nil },
                set: { if !$0 { viewModel.exportedFileURL = nil } }
            )) {
                if let url = viewModel.exportedFileURL {
                    ActivityView(items: [url])
                }
            }
            .alert("Erro ao exportar", isPresented: Binding(
                get: { viewModel.exportError != nil },
                set: { if !$0 { viewModel.exportError = nil } }
            )) {
                Button("OK", role: .cancel) { }
            } message: {
                if let msg = viewModel.exportError { Text(msg) }
            }
        }
    }
}

private struct ActivityView: UIViewControllerRepresentable {
    let items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - Date Filter

private extension DashboardView {

    var dateFilterSection: some View {
        VStack(spacing: 10) {
            HStack(spacing: 12) {
                Picker("Período", selection: Binding(
                    get: { viewModel.selectedPreset },
                    set: { viewModel.selectPreset($0) }
                )) {
                    ForEach(DateRangePreset.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)

                Button {
                    showExportOptions = true
                } label: {
                    if viewModel.isExporting {
                        ProgressView()
                            .frame(width: 20, height: 20)
                    } else {
                        Image(systemName: "square.and.arrow.up")
                            .font(.title2)
                            .foregroundColor(brandColor)
                    }
                }
                .disabled(viewModel.isExporting)
                .confirmationDialog("Exportar Relatório", isPresented: $showExportOptions) {
                    Button("Exportar CSV") { Task { await viewModel.exportOrders(format: "csv") } }
                    Button("Exportar PDF") { Task { await viewModel.exportOrders(format: "pdf") } }
                    Button("Cancelar", role: .cancel) { }
                }
            }

            if viewModel.selectedPreset == .custom {
                VStack(spacing: 8) {
                    DatePicker("De", selection: $viewModel.startDate, displayedComponents: .date)
                    DatePicker("Até", selection: $viewModel.endDate, in: viewModel.startDate..., displayedComponents: .date)
                    Button("Aplicar") { Task { await viewModel.loadAll() } }
                        .buttonStyle(.borderedProminent)
                        .tint(brandColor)
                }
                .padding()
                .background(Color(uiColor: .secondarySystemBackground))
                .cornerRadius(12)
            }
        }
    }
}

// MARK: - Summary

private extension DashboardView {

    func summarySection(_ summary: DashboardSummary) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            DashboardSectionHeader(title: "RESUMO")
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                MetricCard(title: "Receita", value: formatCurrency(summary.totalRevenue), icon: "banknote.fill", color: .green)
                MetricCard(title: "Pedidos", value: "\(summary.totalOrders)", icon: "cart.fill", color: .blue)
                MetricCard(title: "Ticket Médio", value: formatCurrency(summary.averageRevenuePerOrder), icon: "chart.line.uptrend.xyaxis", color: brandColor)
                MetricCard(title: "Descontos", value: formatCurrency(summary.totalDiscount), icon: "tag.fill", color: .orange)
            }
        }
    }
}

// MARK: - Order Status

private extension DashboardView {

    func statusSection(_ summary: DashboardSummary) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            DashboardSectionHeader(title: "STATUS DOS PEDIDOS")
            VStack(spacing: 12) {
                OrderStatusBar(label: "Entregues", count: summary.completedOrders, total: summary.totalOrders, color: .green)
                OrderStatusBar(label: "Preparando", count: summary.pendingOrders, total: summary.totalOrders, color: .yellow)
                OrderStatusBar(label: "Cancelados", count: summary.canceledOrders, total: summary.totalOrders, color: .red)
            }
            .padding()
            .background(Color(uiColor: .secondarySystemBackground))
            .cornerRadius(12)
        }
    }
}

// MARK: - Revenue Chart

private extension DashboardView {

    var revenueChartSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            DashboardSectionHeader(title: "RECEITA AO LONGO DO TEMPO")
            Chart(viewModel.revenueOverTime) { point in
                BarMark(
                    x: .value("Data", point.parsedDate, unit: .day),
                    y: .value("Receita", Double(point.revenue) / 100.0)
                )
                .foregroundStyle(brandColor)
            }
            .chartXAxis {
                AxisMarks(values: .automatic(desiredCount: 5)) {
                    AxisValueLabel(format: .dateTime.day().month(.abbreviated))
                    AxisGridLine()
                }
            }
            .chartYAxis {
                AxisMarks { value in
                    AxisValueLabel {
                        if let amount = value.as(Double.self) {
                            Text(formatCurrencyCompact(amount)).font(.caption2)
                        }
                    }
                    AxisGridLine()
                }
            }
            .frame(height: 200)
            .padding()
            .background(Color(uiColor: .secondarySystemBackground))
            .cornerRadius(12)
        }
    }
}

// MARK: - Top Products

private extension DashboardView {

    var topProductsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            DashboardSectionHeader(title: "TOP PRODUTOS")
            let maxRevenue = viewModel.topProducts.map(\.totalRevenue).max() ?? 1
            VStack(spacing: 0) {
                ForEach(Array(viewModel.topProducts.enumerated()), id: \.element.id) { index, product in
                    VStack(spacing: 6) {
                        HStack {
                            Text("\(index + 1). \(product.productName)")
                                .font(.subheadline)
                                .lineLimit(1)
                            Spacer()
                            Text(formatCurrency(product.totalRevenue))
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundColor(brandColor)
                        }
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 4).fill(brandColor.opacity(0.15))
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(brandColor)
                                    .frame(width: geo.size.width * (Double(product.totalRevenue) / Double(maxRevenue)))
                            }
                        }
                        .frame(height: 6)
                        Text("\(product.totalQuantitySold) unid. · \(product.orderCount) pedido\(product.orderCount != 1 ? "s" : "")")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(.vertical, 10)
                    .padding(.horizontal)
                    if index < viewModel.topProducts.count - 1 {
                        Divider().padding(.leading)
                    }
                }
            }
            .background(Color(uiColor: .secondarySystemBackground))
            .cornerRadius(12)
        }
    }
}

// MARK: - Top Clients

private extension DashboardView {

    var topClientsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            DashboardSectionHeader(title: "TOP CLIENTES")
            VStack(spacing: 0) {
                ForEach(Array(viewModel.topClients.enumerated()), id: \.element.id) { index, client in
                    HStack(spacing: 12) {
                        Text("\(index + 1)")
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .frame(width: 22, height: 22)
                            .background(brandColor)
                            .clipShape(Circle())

                        VStack(alignment: .leading, spacing: 2) {
                            Text(client.clientName).fontWeight(.medium)
                            Text("\(client.orderCount) pedido\(client.orderCount != 1 ? "s" : "")")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        Spacer()

                        Text(formatCurrency(client.totalRevenue))
                            .fontWeight(.semibold)
                            .foregroundColor(brandColor)
                    }
                    .padding(.vertical, 10)
                    .padding(.horizontal)
                    if index < viewModel.topClients.count - 1 {
                        Divider().padding(.leading)
                    }
                }
            }
            .background(Color(uiColor: .secondarySystemBackground))
            .cornerRadius(12)
        }
    }
}

// MARK: - Helpers

private extension DashboardView {

    func formatCurrency(_ cents: Int) -> String {
        Formatters.currency.string(from: NSNumber(value: Double(cents) / 100.0)) ?? "R$ 0,00"
    }

    func formatCurrencyCompact(_ value: Double) -> String {
        value >= 1000
            ? String(format: "R$%.1fk", value / 1000)
            : String(format: "R$%.0f", value)
    }
}

// MARK: - Subviews

struct DashboardSectionHeader: View {
    let title: String
    var body: some View {
        Text(title)
            .font(.caption)
            .fontWeight(.bold)
            .foregroundColor(.secondary)
    }
}

struct MetricCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: icon).foregroundColor(color).font(.title3)
            Text(value)
                .font(.title3)
                .fontWeight(.bold)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(title).font(.caption).foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(uiColor: .secondarySystemBackground))
        .cornerRadius(12)
    }
}

struct OrderStatusBar: View {
    let label: String
    let count: Int
    let total: Int
    let color: Color

    private var fraction: Double {
        guard total > 0 else { return 0 }
        return Double(count) / Double(total)
    }

    var body: some View {
        VStack(spacing: 6) {
            HStack {
                Text(label).font(.subheadline)
                Spacer()
                Text("\(count)").font(.subheadline).fontWeight(.semibold)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4).fill(color.opacity(0.2))
                    RoundedRectangle(cornerRadius: 4)
                        .fill(color)
                        .frame(width: geo.size.width * fraction)
                }
            }
            .frame(height: 8)
        }
    }
}
