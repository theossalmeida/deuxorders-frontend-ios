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

    private let brandColor = Color(red: 88/255, green: 22/255, blue: 41/255)

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
                    ForEach(viewModel.filteredEntries) { entry in
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
                }
                .listStyle(.plain)
            }
        }
        .navigationTitle("Lançamentos")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                NavigationLink(destination: CashEntryFormView(viewModel: viewModel)) {
                    Image(systemName: "plus")
                        .foregroundColor(brandColor)
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
                    Task { await viewModel.deleteEntry(id: entry.id, reason: deleteReason.isEmpty ? "Removido pelo app" : deleteReason) }
                }
                entryToDelete = nil
            }
        } message: {
            Text("Informe o motivo para excluir este lançamento.")
        }
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
}
