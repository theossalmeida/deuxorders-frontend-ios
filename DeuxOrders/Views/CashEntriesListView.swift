//
//  CashEntriesListView.swift
//  DeuxOrders
//

import SwiftUI

struct CashEntriesListView: View {
    @ObservedObject var viewModel: CashFlowViewModel
    @State private var showDeleteAlert = false
    @State private var deleteReason = ""
    @State private var entryToDelete: CashFlowEntry?

    private var groupedEntries: [(date: Date, entries: [CashFlowEntry])] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: viewModel.filteredEntries) { entry in
            calendar.startOfDay(for: entry.billingDate)
        }
        return grouped.map { date, entries in
            (
                date: date,
                entries: entries.sorted { $0.billingDate > $1.billingDate }
            )
        }
        .sorted { $0.date > $1.date }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Type filter
            Picker("Tipo", selection: $viewModel.selectedTypeFilter) {
                Text("Todos").tag(CashFlowEntryType?.none)
                Text("Entradas").tag(CashFlowEntryType?.some(.inflow))
                Text("Saídas").tag(CashFlowEntryType?.some(.outflow))
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            .padding(.top, 12)

            // Search
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                TextField("Buscar por descrição...", text: $viewModel.searchText)
                    .textFieldStyle(.plain)
                if !viewModel.searchText.isEmpty {
                    Button { viewModel.searchText = "" } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(10)
            .background(Color(uiColor: .secondarySystemBackground))
            .cornerRadius(10)
            .padding(.horizontal)
            .padding(.top, 12)

            // Summary band
            if let summary = viewModel.summary {
                summaryBand(summary)
                    .padding(.horizontal)
                    .padding(.top, 12)
            }

            if viewModel.isLoading {
                ProgressView("Carregando...")
                    .frame(maxWidth: .infinity)
                    .padding(.top, 60)
                Spacer()
            } else if viewModel.filteredEntries.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "tray")
                        .font(.largeTitle)
                        .foregroundColor(.secondary)
                    Text("Sem lançamentos")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 60)
                Spacer()
            } else {
                List {
                    ForEach(groupedEntries, id: \.date) { group in
                        Section {
                            ForEach(group.entries) { entry in
                                NavigationLink(destination: CashEntryDetailView(entry: entry, viewModel: viewModel)) {
                                    CashEntryRowView(entry: entry)
                                }
                                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                    Button(role: .destructive) {
                                        entryToDelete = entry
                                        deleteReason = ""
                                        showDeleteAlert = true
                                    } label: {
                                        Label("Excluir", systemImage: "trash")
                                    }
                                }
                            }
                        } header: {
                            dayHeader(date: group.date, entries: group.entries)
                        }
                    }
                }
                .listStyle(.plain)
            }
        }
        .navigationTitle("Lançamentos")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                NavigationLink(destination: CashEntryFormView(viewModel: viewModel)) {
                    Image(systemName: "plus")
                        .foregroundColor(DSColor.brand)
                }
            }
        }
        .task { await viewModel.loadEntries() }
        .refreshable { await viewModel.loadEntries() }
        .alert("Motivo da exclusão", isPresented: $showDeleteAlert) {
            TextField("Informe o motivo", text: $deleteReason)
            Button("Cancelar", role: .cancel) { entryToDelete = nil }
            Button("Excluir", role: .destructive) {
                if let entry = entryToDelete {
                    Task { await viewModel.deleteEntry(id: entry.id, reason: normalizedDeleteReason) }
                }
                entryToDelete = nil
            }
        } message: {
            Text("Informe o motivo para excluir este lançamento.")
        }
    }

    private func dayHeader(date: Date, entries: [CashFlowEntry]) -> some View {
        let net = entries.reduce(0) { total, entry in
            total + (entry.type == .inflow ? entry.amountCents : -entry.amountCents)
        }

        return HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(Formatters.relativeDay(date))
                    .font(.caption.weight(.bold))
                    .foregroundColor(DSColor.foreground)
                Text("\(entries.count) lançamento\(entries.count == 1 ? "" : "s")")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            Spacer()
            Text(signedCurrency(net))
                .font(.system(size: 12, weight: .semibold, design: .monospaced))
                .foregroundColor(net >= 0 ? DSColor.ok : DSColor.destructive)
        }
        .padding(.vertical, 6)
        .textCase(nil)
    }

    private func summaryBand(_ summary: CashFlowSummary) -> some View {
        HStack(spacing: 0) {
            summaryItem(label: "Entradas", cents: summary.totalInflowCents, color: .green)
            Divider().frame(height: 32)
            summaryItem(label: "Saídas", cents: summary.totalOutflowCents, color: .red)
            Divider().frame(height: 32)
            summaryItem(label: "Saldo", cents: summary.netBalanceCents, color: summary.netBalanceCents >= 0 ? .green : .red)
        }
        .padding(.vertical, 10)
        .background(Color(uiColor: .secondarySystemBackground))
        .cornerRadius(10)
    }

    private func summaryItem(label: String, cents: Int, color: Color) -> some View {
        VStack(spacing: 2) {
            Text(label.uppercased())
                .font(.system(size: 9, weight: .semibold))
                .foregroundColor(.secondary)
            Text(Formatters.currency.string(from: NSNumber(value: Double(cents) / 100.0)) ?? "R$ 0,00")
                .font(.system(size: 12, weight: .semibold, design: .monospaced))
                .foregroundColor(color)
        }
        .frame(maxWidth: .infinity)
    }

    private func signedCurrency(_ cents: Int) -> String {
        let sign = cents >= 0 ? "+" : "-"
        let amount = Formatters.brl(abs(cents))
        return "\(sign)\(amount)"
    }

    private var normalizedDeleteReason: String {
        let trimmed = deleteReason.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.count >= 5 ? trimmed : "Removido pelo app"
    }
}
