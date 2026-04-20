//
//  CashEntryDetailView.swift
//  DeuxOrders
//

import SwiftUI

struct CashEntryDetailView: View {
    let entry: CashFlowEntry
    @ObservedObject var viewModel: CashFlowViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var showDeleteAlert = false
    @State private var deleteReason = ""

    private let brandColor = Color(red: 88/255, green: 22/255, blue: 41/255)
    private var isInflow: Bool { entry.type == .inflow }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Amount hero
                amountCard

                // Details
                detailsCard

                // Source info
                sourceCard

                // Actions
                actionsSection
            }
            .padding()
        }
        .navigationTitle("Lançamento")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                if entry.source == .manual {
                    NavigationLink(destination: CashEntryFormView(viewModel: viewModel, editingEntry: entry)) {
                        Text("Editar")
                            .foregroundColor(brandColor)
                    }
                }
            }
        }
        .alert("Motivo da exclusão", isPresented: $showDeleteAlert) {
            TextField("Informe o motivo", text: $deleteReason)
            Button("Cancelar", role: .cancel) { }
            Button("Excluir", role: .destructive) {
                Task {
                    await viewModel.deleteEntry(id: entry.id, reason: deleteReason.isEmpty ? "Removido pelo app" : deleteReason)
                    dismiss()
                }
            }
        } message: {
            Text("Informe o motivo para excluir este lançamento.")
        }
    }

    // MARK: - Amount Card

    private var amountCard: some View {
        VStack(spacing: 8) {
            // Type badge
            Text(entry.type.localizedName.uppercased())
                .font(.system(size: 10, weight: .bold))
                .tracking(1.5)
                .foregroundColor(entry.type.color)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(entry.type.color.opacity(0.1))
                .cornerRadius(6)

            Text("\(isInflow ? "+" : "−")\(formatCurrency(entry.amountCents))")
                .font(.system(size: 36, weight: .bold, design: .monospaced))
                .foregroundColor(isInflow ? .green : .primary)

            Text(entry.counterparty)
                .font(.headline)
                .foregroundColor(.primary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .background(Color(uiColor: .secondarySystemBackground))
        .cornerRadius(16)
    }

    // MARK: - Details Card

    private var detailsCard: some View {
        VStack(spacing: 0) {
            detailRow(label: "Categoria", icon: entry.category.icon) {
                HStack(spacing: 6) {
                    Circle()
                        .fill(entry.category.color)
                        .frame(width: 8, height: 8)
                    Text(entry.category.localizedName)
                        .font(.subheadline)
                }
            }

            Divider().padding(.leading, 48)

            detailRow(label: "Data", icon: "calendar") {
                Text(formatDateLong(entry.billingDate))
                    .font(.subheadline)
            }

            if let notes = entry.notes, !notes.isEmpty {
                Divider().padding(.leading, 48)

                detailRow(label: "Observações", icon: "text.alignleft") {
                    Text(notes)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
        }
        .background(Color(uiColor: .secondarySystemBackground))
        .cornerRadius(12)
    }

    // MARK: - Source Card

    private var sourceCard: some View {
        VStack(spacing: 0) {
            detailRow(label: "Origem", icon: "link") {
                HStack(spacing: 6) {
                    Text(entry.source.localizedName)
                        .font(.subheadline)
                    if entry.source != .manual {
                        Text("(automático)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }

            Divider().padding(.leading, 48)

            detailRow(label: "Registrado por", icon: "person") {
                Text(entry.authorUserName)
                    .font(.subheadline)
            }

            Divider().padding(.leading, 48)

            detailRow(label: "Criado em", icon: "clock") {
                Text(formatDateLong(entry.createdAt))
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
        .background(Color(uiColor: .secondarySystemBackground))
        .cornerRadius(12)
    }

    // MARK: - Actions

    private var actionsSection: some View {
        VStack(spacing: 12) {
            if entry.source == .manual {
                Button(role: .destructive) {
                    deleteReason = ""
                    showDeleteAlert = true
                } label: {
                    HStack {
                        Image(systemName: "trash")
                        Text("Excluir lançamento")
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                }
                .background(Color.red.opacity(0.1))
                .cornerRadius(12)
            }
        }
    }

    // MARK: - Helpers

    private func detailRow<Content: View>(label: String, icon: String, @ViewBuilder content: () -> Content) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(label.uppercased())
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundColor(.secondary)
                content()
            }

            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    private func formatCurrency(_ cents: Int) -> String {
        Formatters.currency.string(from: NSNumber(value: Double(cents) / 100.0)) ?? "R$ 0,00"
    }

    private func formatDateLong(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "pt_BR")
        formatter.dateStyle = .long
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}
