//
//  CashDashboardView.swift
//  DeuxOrders
//

import SwiftUI
import Charts

struct CashDashboardView: View {
    @ObservedObject var viewModel: CashFlowViewModel

    private let brandColor = Color(red: 88/255, green: 22/255, blue: 41/255)

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
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
                } else {
                    heroBalanceCard
                    if !viewModel.chartData.isEmpty {
                        flowChartSection
                    }
                    if !viewModel.categoryBreakdown.isEmpty {
                        categoryBreakdownSection
                    }
                    recentEntriesSection
                }
            }
            .padding()
        }
        .navigationTitle("Caixa")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                NavigationLink(destination: CashEntryFormView(viewModel: viewModel)) {
                    Image(systemName: "plus")
                        .foregroundColor(brandColor)
                }
            }
        }
        .task { await viewModel.loadDashboard() }
        .refreshable { await viewModel.loadDashboard() }
    }
}

// MARK: - Date Filter

private extension CashDashboardView {

    var dateFilterSection: some View {
        VStack(spacing: 10) {
            Picker("Período", selection: Binding(
                get: { viewModel.selectedPreset },
                set: { viewModel.selectPreset($0) }
            )) {
                ForEach(DateRangePreset.allCases, id: \.self) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)

            if viewModel.selectedPreset == .custom {
                VStack(spacing: 8) {
                    DatePicker("De", selection: $viewModel.startDate, displayedComponents: .date)
                    DatePicker("Até", selection: $viewModel.endDate, in: viewModel.startDate..., displayedComponents: .date)
                    Button("Aplicar") { Task { await viewModel.loadDashboard() } }
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

// MARK: - Hero Balance Card

private extension CashDashboardView {

    var heroBalanceCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Saldo líquido · \(periodLabel)")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.white.opacity(0.75))

                Text(formatCurrency(viewModel.summary?.netBalanceCents ?? 0))
                    .font(.system(size: 36, weight: .semibold, design: .monospaced))
                    .foregroundColor(.white)
            }

            HStack(spacing: 10) {
                balanceChip(title: "Entradas", icon: "arrow.down", amount: viewModel.summary?.totalInflowCents ?? 0)
                balanceChip(title: "Saídas", icon: "arrow.up", amount: viewModel.summary?.totalOutflowCents ?? 0)
                if let count = viewModel.summary?.totalCount {
                    countChip(title: "Lançamentos", count: count)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(
            LinearGradient(
                gradient: Gradient(colors: [brandColor, brandColor.opacity(0.8)]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .cornerRadius(16)
    }

    func balanceChip(title: String, icon: String, amount: Int) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 9))
                Text(title.uppercased())
                    .font(.system(size: 9, weight: .semibold))
            }
            .foregroundColor(.white.opacity(0.75))

            Text(formatCurrency(amount))
                .font(.system(size: 13, weight: .semibold, design: .monospaced))
                .foregroundColor(.white)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color.white.opacity(0.1))
        .cornerRadius(10)
    }

    func countChip(title: String, count: Int) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title.uppercased())
                .font(.system(size: 9, weight: .semibold))
                .foregroundColor(.white.opacity(0.75))

            Text("\(count)")
                .font(.system(size: 13, weight: .semibold, design: .monospaced))
                .foregroundColor(.white)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color.white.opacity(0.1))
        .cornerRadius(10)
    }

    var periodLabel: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "pt_BR")
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: Date())
    }
}

// MARK: - Flow Chart

private extension CashDashboardView {

    var flowChartSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Fluxo")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Spacer()
                HStack(spacing: 12) {
                    Label("Entradas", systemImage: "circle.fill")
                        .font(.system(size: 10))
                        .foregroundColor(.green)
                    Label("Saídas", systemImage: "circle.fill")
                        .font(.system(size: 10))
                        .foregroundColor(.red)
                }
            }

            Chart(viewModel.chartData) { point in
                BarMark(
                    x: .value("Data", point.date, unit: .day),
                    y: .value("Valor", Double(point.inflowCents) / 100.0)
                )
                .foregroundStyle(.green)
                .position(by: .value("Tipo", "Entrada"))

                BarMark(
                    x: .value("Data", point.date, unit: .day),
                    y: .value("Valor", Double(point.outflowCents) / 100.0)
                )
                .foregroundStyle(.red.opacity(0.8))
                .position(by: .value("Tipo", "Saída"))
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
        }
        .padding()
        .background(Color(uiColor: .secondarySystemBackground))
        .cornerRadius(12)
    }
}

// MARK: - Category Breakdown

private extension CashDashboardView {

    var categoryBreakdownSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            DashboardSectionHeader(title: "SAÍDAS POR CATEGORIA")

            VStack(spacing: 0) {
                let maxAmount = viewModel.categoryBreakdown.map(\.amount).max() ?? 1

                ForEach(Array(viewModel.categoryBreakdown.enumerated()), id: \.element.category) { index, item in
                    HStack(spacing: 12) {
                        Image(systemName: item.category.icon)
                            .font(.caption)
                            .foregroundColor(item.category.color)
                            .frame(width: 24)

                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(item.category.localizedName)
                                    .font(.subheadline)
                                Spacer()
                                Text(formatCurrency(item.amount))
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                            }

                            GeometryReader { geo in
                                ZStack(alignment: .leading) {
                                    RoundedRectangle(cornerRadius: 3)
                                        .fill(item.category.color.opacity(0.15))
                                    RoundedRectangle(cornerRadius: 3)
                                        .fill(item.category.color)
                                        .frame(width: geo.size.width * (Double(item.amount) / Double(maxAmount)))
                                }
                            }
                            .frame(height: 5)
                        }
                    }
                    .padding(.vertical, 8)
                    .padding(.horizontal)

                    if index < viewModel.categoryBreakdown.count - 1 {
                        Divider().padding(.leading, 52)
                    }
                }
            }
            .background(Color(uiColor: .secondarySystemBackground))
            .cornerRadius(12)
        }
    }
}

// MARK: - Recent Entries

private extension CashDashboardView {

    var recentEntriesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Últimos lançamentos")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Spacer()
                NavigationLink(destination: CashEntriesListView(viewModel: viewModel)) {
                    Text("Ver tudo →")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(brandColor)
                }
            }

            if viewModel.recentEntries.isEmpty {
                Text("Sem lançamentos no período")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 24)
                    .background(Color(uiColor: .secondarySystemBackground))
                    .cornerRadius(12)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(viewModel.recentEntries.enumerated()), id: \.element.id) { index, entry in
                        CashEntryRowView(entry: entry)
                        if index < viewModel.recentEntries.count - 1 {
                            Divider().padding(.leading, 48)
                        }
                    }
                }
                .background(Color(uiColor: .secondarySystemBackground))
                .cornerRadius(12)
            }
        }
    }
}

// MARK: - Helpers

private extension CashDashboardView {

    func formatCurrency(_ cents: Int) -> String {
        Formatters.currency.string(from: NSNumber(value: Double(cents) / 100.0)) ?? "R$ 0,00"
    }

    func formatCurrencyCompact(_ value: Double) -> String {
        value >= 1000
            ? String(format: "R$%.1fk", value / 1000)
            : String(format: "R$%.0f", value)
    }
}

// MARK: - Cash Entry Row (shared component)

struct CashEntryRowView: View {
    let entry: CashFlowEntry

    private var isInflow: Bool { entry.type == .inflow }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: entry.type.icon)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(entry.type.color)
                .frame(width: 28, height: 28)
                .background(entry.type.color.opacity(0.1))
                .cornerRadius(8)

            VStack(alignment: .leading, spacing: 2) {
                Text(entry.counterparty)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .lineLimit(1)

                Text("\(formatDate(entry.billingDate)) · \(entry.category.localizedName)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Text("\(isInflow ? "+" : "−")\(formatAmount(entry.amountCents))")
                .font(.system(size: 13, weight: .semibold, design: .monospaced))
                .foregroundColor(isInflow ? .green : .primary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    private func formatAmount(_ cents: Int) -> String {
        Formatters.currency.string(from: NSNumber(value: Double(cents) / 100.0)) ?? "R$ 0,00"
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "pt_BR")
        formatter.dateFormat = "d MMM"
        return formatter.string(from: date)
    }
}
