//
//  ProductDetailView.swift
//  DeuxOrders
//

import SwiftUI

struct ProductDetailView: View {
    let product: ProductResponse
    @ObservedObject var viewModel: ProductsViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var isEditing = false
    @State private var editName: String = ""
    @State private var editDescription: String = ""
    @State private var editPrice: String = ""
    @State private var editCategory: String = ""
    @State private var editSize: String = ""
    @State private var showDeleteAlert = false


    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Product Image
                productImageSection

                // Product Info
                productInfoCard

                // Performance (placeholder)
                performanceCard

                // Price
                priceCard

                // Status
                statusSection

                // Delete
                deleteSection
            }
            .padding()
        }
        .navigationTitle(product.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(isEditing ? "Salvar" : "Editar") {
                    if isEditing {
                        Task { await saveChanges() }
                    } else {
                        startEditing()
                    }
                }
                .foregroundColor(DSColor.brand)
            }
        }
        .alert("Excluir produto?", isPresented: $showDeleteAlert) {
            Button("Cancelar", role: .cancel) { }
            Button("Excluir", role: .destructive) {
                Task {
                    await viewModel.deleteProduct(id: product.id)
                    dismiss()
                }
            }
        } message: {
            Text("Esta ação não pode ser desfeita.")
        }
    }

    // MARK: - Image

    private var productImageSection: some View {
        Group {
            if let imageUrl = product.image, let url = URL(string: imageUrl) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(height: 200)
                            .clipped()
                            .cornerRadius(16)
                    case .failure:
                        imagePlaceholder
                    default:
                        ProgressView()
                            .frame(height: 200)
                    }
                }
            } else {
                imagePlaceholder
            }
        }
    }

    private var imagePlaceholder: some View {
        VStack(spacing: 8) {
            Image(systemName: "photo")
                .font(.largeTitle)
                .foregroundColor(.secondary)
            Text("Sem imagem")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 160)
        .background(Color(uiColor: .secondarySystemBackground))
        .cornerRadius(16)
    }

    // MARK: - Info Card

    private var productInfoCard: some View {
        VStack(spacing: 0) {
            if isEditing {
                editableInfoFields
            } else {
                readOnlyInfo
            }
        }
        .background(Color(uiColor: .secondarySystemBackground))
        .cornerRadius(12)
    }

    private var readOnlyInfo: some View {
        VStack(spacing: 0) {
            infoRow(label: "Nome", value: product.name)

            if let desc = product.description, !desc.isEmpty {
                Divider().padding(.leading)
                infoRow(label: "Descrição", value: desc)
            }

            if let cat = product.category, !cat.isEmpty {
                Divider().padding(.leading)
                infoRow(label: "Categoria", value: cat)
            }

            if let size = product.size, !size.isEmpty {
                Divider().padding(.leading)
                infoRow(label: "Tamanho", value: size)
            }
        }
    }

    private var editableInfoFields: some View {
        VStack(spacing: 12) {
            editField(label: "Nome", text: $editName)
            editField(label: "Descrição", text: $editDescription)
            editField(label: "Categoria", text: $editCategory)
            editField(label: "Tamanho", text: $editSize)
        }
        .padding()
    }

    // MARK: - Performance

    private var performanceCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            DashboardSectionHeader(title: "DESEMPENHO")
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("—")
                        .font(.title2)
                        .fontWeight(.bold)
                    Text("Unid. vendidas")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
                .background(Color(uiColor: .tertiarySystemBackground))
                .cornerRadius(8)

                VStack(alignment: .leading, spacing: 4) {
                    Text("—")
                        .font(.title2)
                        .fontWeight(.bold)
                    Text("Receita")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
                .background(Color(uiColor: .tertiarySystemBackground))
                .cornerRadius(8)
            }
        }
        .padding()
        .background(Color(uiColor: .secondarySystemBackground))
        .cornerRadius(12)
    }

    // MARK: - Price

    private var priceCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            DashboardSectionHeader(title: "PREÇO")

            if isEditing {
                TextField("Preço", text: $editPrice)
                    .keyboardType(.decimalPad)
                    .textFieldStyle(.roundedBorder)
            } else {
                Text(formatPrice(product.price))
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(DSColor.brand)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(uiColor: .secondarySystemBackground))
        .cornerRadius(12)
    }

    // MARK: - Status

    private var statusSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Status")
                    .font(.subheadline)
                    .fontWeight(.medium)
                Text(product.status ? "Ativo" : "Inativo")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Toggle("", isOn: Binding(
                get: { product.status },
                set: { newValue in
                    Task {
                        if newValue {
                            await viewModel.activateProduct(id: product.id)
                        } else {
                            await viewModel.deactivateProduct(id: product.id)
                        }
                    }
                }
            ))
            .tint(DSColor.brand)
        }
        .padding()
        .background(Color(uiColor: .secondarySystemBackground))
        .cornerRadius(12)
    }

    // MARK: - Delete

    private var deleteSection: some View {
        Button(role: .destructive) {
            showDeleteAlert = true
        } label: {
            HStack {
                Image(systemName: "trash")
                Text("Excluir produto")
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
        }
        .background(Color.red.opacity(0.1))
        .cornerRadius(12)
    }

    // MARK: - Helpers

    private func infoRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .font(.subheadline)
                .multilineTextAlignment(.trailing)
        }
        .padding(.vertical, 10)
        .padding(.horizontal)
    }

    private func editField(label: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
            TextField(label, text: text)
                .textFieldStyle(.roundedBorder)
        }
    }

    private func startEditing() {
        editName = product.name
        editDescription = product.description ?? ""
        editPrice = String(format: "%.2f", product.price).replacingOccurrences(of: ".", with: ",")
        editCategory = product.category ?? ""
        editSize = product.size ?? ""
        isEditing = true
    }

    private func saveChanges() async {
        let priceValue = Double(editPrice.replacingOccurrences(of: ",", with: ".")) ?? product.price
        let _ = await viewModel.updateProduct(
            id: product.id,
            name: editName,
            description: editDescription,
            price: priceValue,
            category: editCategory.isEmpty ? nil : editCategory,
            size: editSize.isEmpty ? nil : editSize
        )
        isEditing = false
    }

    private func formatPrice(_ price: Double) -> String {
        Formatters.currency.string(from: NSNumber(value: price / 100.0)) ?? "R$ 0,00"
    }
}
