//
//  CashEntryFormView.swift
//  DeuxOrders
//

import SwiftUI

struct CashEntryFormView: View {
    @ObservedObject var viewModel: CashFlowViewModel
    @Environment(\.dismiss) private var dismiss

    var editingEntry: CashFlowEntry?

    @State private var entryType: CashFlowEntryType = .inflow
    @State private var amountString: String = "0,00"
    @State private var counterparty: String = ""
    @State private var category: CashFlowCategory = .other
    @State private var billingDate: Date = Date()
    @State private var notes: String = ""
    @State private var isSaving = false


    private var isEditing: Bool { editingEntry != nil }

    private var parsedAmountCents: Int {
        let cleaned = amountString.replacingOccurrences(of: ".", with: "").replacingOccurrences(of: ",", with: ".")
        return Int((Double(cleaned) ?? 0) * 100)
    }

    private var isValid: Bool {
        parsedAmountCents > 0 && !counterparty.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Type toggle
                typeToggle

                // Big value input
                valueInputCard

                // Fields
                fieldsCard
            }
            .padding()
        }
        .navigationTitle(isEditing ? "Editar lançamento" : "Novo lançamento")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(isSaving ? "Salvando..." : "Salvar") {
                    Task { await save() }
                }
                .disabled(!isValid || isSaving)
                .fontWeight(.semibold)
                .foregroundColor(DSColor.brand)
            }
        }
        .onAppear { populateFromEntry() }
    }

    // MARK: - Type Toggle

    private var typeToggle: some View {
        HStack(spacing: 4) {
            typeButton(type: .inflow, label: "↓ Entrada")
            typeButton(type: .outflow, label: "↑ Saída")
        }
        .padding(4)
        .background(Color(uiColor: .tertiarySystemBackground))
        .cornerRadius(12)
    }

    private func typeButton(type: CashFlowEntryType, label: String) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) { entryType = type }
        } label: {
            Text(label)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(entryType == type ? type.color : .secondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(entryType == type ? Color(uiColor: .systemBackground) : Color.clear)
                .cornerRadius(10)
                .shadow(color: entryType == type ? .black.opacity(0.05) : .clear, radius: 2, y: 1)
        }
    }

    // MARK: - Value Input

    private var valueInputCard: some View {
        VStack(spacing: 8) {
            Text("VALOR")
                .font(.system(size: 10, weight: .semibold))
                .tracking(1.5)
                .foregroundColor(.secondary)

            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text("R$")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundColor(.secondary)

                TextField("0,00", text: $amountString)
                    .font(.system(size: 44, weight: .semibold, design: .monospaced))
                    .foregroundColor(entryType.color)
                    .multilineTextAlignment(.center)
                    .keyboardType(.numberPad)
                    .onChange(of: amountString) { _, newValue in
                        formatAmount(newValue)
                    }
            }
        }
        .padding(.vertical, 24)
        .frame(maxWidth: .infinity)
        .background(Color(uiColor: .secondarySystemBackground))
        .cornerRadius(12)
    }

    // MARK: - Fields

    private var fieldsCard: some View {
        VStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                fieldLabel("DESCRIÇÃO")
                TextField("Ex: Fornecedor Ingredientes", text: $counterparty)
                    .textFieldStyle(.roundedBorder)
            }

            VStack(alignment: .leading, spacing: 6) {
                fieldLabel("CATEGORIA")
                Picker("Categoria", selection: $category) {
                    ForEach(CashFlowCategory.allCases, id: \.self) { cat in
                        Text(cat.localizedName).tag(cat)
                    }
                }
                .pickerStyle(.menu)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(8)
                .background(Color(uiColor: .systemBackground))
                .cornerRadius(8)
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color(uiColor: .separator), lineWidth: 0.5))
            }

            VStack(alignment: .leading, spacing: 6) {
                fieldLabel("DATA")
                DatePicker("", selection: $billingDate, displayedComponents: .date)
                    .datePickerStyle(.compact)
                    .labelsHidden()
            }

            VStack(alignment: .leading, spacing: 6) {
                fieldLabel("OBSERVAÇÕES")
                TextField("Notas adicionais (opcional)", text: $notes, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .lineLimit(2...4)
            }
        }
        .padding()
        .background(Color(uiColor: .secondarySystemBackground))
        .cornerRadius(12)
    }

    private func fieldLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 10, weight: .semibold))
            .tracking(1)
            .foregroundColor(.secondary)
    }

    // MARK: - Actions

    private func formatAmount(_ value: String) {
        let digits = value.filter { $0.isNumber }
        let num = Int(digits) ?? 0
        let formatted = String(format: "%d,%02d", num / 100, num % 100)
        if amountString != formatted {
            amountString = formatted
        }
    }

    private func populateFromEntry() {
        guard let entry = editingEntry else { return }
        entryType = entry.type
        counterparty = entry.counterparty
        category = entry.category
        billingDate = entry.billingDate
        notes = entry.notes ?? ""
        let cents = entry.amountCents
        amountString = String(format: "%d,%02d", cents / 100, cents % 100)
    }

    private func save() async {
        isSaving = true
        defer { isSaving = false }

        let input = CreateCashFlowEntryInput(
            billingDate: Formatters.utcISOForStartOfLocalDay(billingDate),
            type: entryType.rawValue,
            category: category.rawValue,
            counterparty: counterparty.trimmingCharacters(in: .whitespaces),
            amountCents: parsedAmountCents,
            notes: notes.isEmpty ? nil : notes
        )

        let success: Bool
        if let entry = editingEntry {
            success = await viewModel.updateEntry(id: entry.id, input: input)
        } else {
            success = await viewModel.createEntry(input: input)
        }

        if success {
            dismiss()
        }
    }
}
