//
//  ProductsView.swift
//  DeuxOrders
//
//  Created by Theo on 11/03/26.
//


import SwiftUI

struct ProductsView: View {
    @StateObject private var viewModel = ProductsViewModel()
    
    @State private var searchText = ""
    @State private var showActiveOnly = true
    @State private var showAddProductSheet = false
    
    private let brandColor = Color(red: 88/255, green: 22/255, blue: 41/255)

    var filteredProducts: [ProductResponse] {
        viewModel.products.filter { product in
            let searchMatch = searchText.isEmpty || product.name.localizedCaseInsensitiveContains(searchText)
            let statusMatch = product.status == showActiveOnly
            return searchMatch && statusMatch
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                topControlsBar
                contentView
            }
            .navigationTitle("Produtos")
            .task {
                await viewModel.loadProducts()
            }
            .alert("Atenção", isPresented: Binding<Bool>(
                get: { viewModel.errorMessage != nil },
                set: { if !$0 { viewModel.errorMessage = nil } }
            )) {
                Button("OK", role: .cancel) { }
            } message: {
                if let message = viewModel.errorMessage { Text(message) }
            }
            .sheet(isPresented: $showAddProductSheet) {
                AddProductView(viewModel: viewModel)
            }
        }
    }
    
    @ViewBuilder
    private var contentView: some View {
        if viewModel.isLoading && viewModel.products.isEmpty {
            Spacer()
            ProgressView("Buscando produtos...")
            Spacer()
        } else if filteredProducts.isEmpty {
            ContentUnavailableView("Nenhum produto encontrado", systemImage: "shippingbox.fill")
        } else {
            List {
                ForEach(filteredProducts) { product in
                    ProductCard(product: product)
                        .listRowSeparator(.hidden)
                        .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                        .listRowBackground(Color.clear)
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button(role: .destructive) {
                                Task { await viewModel.deleteProduct(id: product.id) }
                            } label: {
                                Label("Excluir", systemImage: "trash.fill")
                            }
                        }
                        .swipeActions(edge: .leading, allowsFullSwipe: true) {
                            if product.status {
                                Button {
                                    Task { await viewModel.deactivateProduct(id: product.id) }
                                } label: {
                                    Label("Desativar", systemImage: "xmark.bin.fill")
                                }
                                .tint(.orange)
                            }
                        }
                }
            }
            .listStyle(.plain)
            .background(Color(uiColor: .systemGroupedBackground))
            .scrollContentBackground(.hidden)
            .refreshable { await viewModel.loadProducts() }
        }
    }
}

private extension ProductsView {
    var topControlsBar: some View {
        HStack(spacing: 12) {
            HStack {
                Image(systemName: "magnifyingglass").foregroundColor(.secondary)
                TextField("Buscar produto...", text: $searchText)
                    .textFieldStyle(.plain)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
            }
            .padding(8)
            .background(Color(uiColor: .secondarySystemBackground))
            .cornerRadius(8)
            
            Menu {
                Picker("Status", selection: $showActiveOnly) {
                    Text("Ativos").tag(true)
                    Text("Inativos").tag(false)
                }
            } label: {
                Image(systemName: "line.3.horizontal.decrease.circle")
                    .font(.title2)
                    .foregroundColor(brandColor)
            }
            
            Button {
                showAddProductSheet = true
            } label: {
                Image(systemName: "plus.circle.fill")
                    .font(.title2)
                    .foregroundColor(brandColor)
            }
        }
        .padding()
        .background(Color(uiColor: .systemBackground))
    }
}

// MARK: - Add Product Sheet

struct AddProductView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: ProductsViewModel
    
    @State private var name = ""
    @State private var description = ""
    @State private var priceString = ""
    @State private var isSubmitting = false
    
    var isFormValid: Bool {
        let isValidName = !name.trimmingCharacters(in: .whitespaces).isEmpty
        let parsedPrice = Double(priceString.replacingOccurrences(of: ",", with: ".")) ?? 0.0
        return isValidName && parsedPrice > 0.0
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Dados do Produto")) {
                    TextField("Nome *", text: $name)
                        .autocorrectionDisabled()
                    
                    TextField("Descrição (Opcional)", text: $description)
                        .autocorrectionDisabled()
                    
                    TextField("Preço (Ex: 15,50) *", text: $priceString)
                        .keyboardType(.decimalPad)
                }
            }
            .navigationTitle("Novo Produto")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Salvar") {
                        submit()
                    }
                    .disabled(!isFormValid || isSubmitting)
                }
            }
            .overlay {
                if isSubmitting {
                    ProgressView()
                        .padding()
                        .background(.ultraThinMaterial)
                        .cornerRadius(8)
                }
            }
        }
        .interactiveDismissDisabled(isSubmitting)
    }
    
    private func submit() {
        isSubmitting = true
        
        let normalizedPrice = priceString.replacingOccurrences(of: ",", with: ".")
        let priceValue = Double(normalizedPrice) ?? 0.0
        
        // Converte e arredonda corretamente para centavos a fim de evitar perda de precisão flutuante.
        let priceInCents = Int(round(priceValue * 100))
        
        Task {
            // Nota: Se a sua assinatura do ViewModel estiver forçando `Double` em vez de `Int`, faça o cast aqui: `Double(priceInCents)`. O ideal no ViewModel é receber `Int`.
            let success = await viewModel.addProduct(name: name, description: description, price: Double(priceInCents))
            isSubmitting = false
            if success {
                dismiss()
            }
        }
    }
}

// MARK: - Product Card

struct ProductCard: View {
    let product: ProductResponse
    
    private var formattedPrice: String {
        // Se a API envia em centavos, o valor em tela DEVE ser dividido por 100 antes da formatação.
        let reaisValue = Double(product.price) / 100.0
        return reaisValue.formatted(.currency(code: "BRL").locale(Locale(identifier: "pt_BR")))
    }
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(product.name)
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    if !product.status {
                        Text("Inativo")
                            .font(.caption2)
                            .fontWeight(.bold)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.gray.opacity(0.2))
                            .foregroundColor(.gray)
                            .cornerRadius(6)
                    }
                }
                
                if let desc = product.description, !desc.isEmpty {
                    Text(desc)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
            }
            
            Spacer()
            
            Text(formattedPrice)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
    }
}
