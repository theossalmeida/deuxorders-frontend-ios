//
//  ProductsView.swift
//  DeuxOrders
//
//  Created by Theo on 11/03/26.
//

import SwiftUI
import PhotosUI
import UniformTypeIdentifiers

struct ProductsView: View {
    @StateObject private var viewModel = ProductsViewModel()

    @State private var searchText = ""
    @State private var statusFilter: Bool? = true
    @State private var selectedCategory: String? = nil
    @State private var showAddProductSheet = false
    @State private var selectedProduct: ProductResponse?


    var availableCategories: [String] {
        let cats = viewModel.products.compactMap { $0.category }.filter { !$0.isEmpty }
        return Array(Set(cats)).sorted()
    }

    var filteredProducts: [ProductResponse] {
        viewModel.products.filter { product in
            let searchMatch = searchText.isEmpty || product.name.localizedCaseInsensitiveContains(searchText)
            let statusMatch = statusFilter == nil || product.status == statusFilter
            let categoryMatch = selectedCategory == nil || product.category == selectedCategory
            return searchMatch && statusMatch && categoryMatch
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
            .sheet(item: $selectedProduct) { product in
                EditProductView(product: product, viewModel: viewModel)
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
            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 156), spacing: 12)], spacing: 12) {
                    ForEach(filteredProducts) { product in
                        NavigationLink {
                            ProductDetailView(product: product, viewModel: viewModel)
                        } label: {
                            ProductCard(product: product)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(16)
            }
            .background(DSColor.background)
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
                Picker("Status", selection: $statusFilter) {
                    Text("Todos").tag(Bool?.none)
                    Text("Ativos").tag(Bool?.some(true))
                    Text("Inativos").tag(Bool?.some(false))
                }
                if !availableCategories.isEmpty {
                    Divider()
                    Picker("Categoria", selection: $selectedCategory) {
                        Text("Todas").tag(String?.none)
                        ForEach(availableCategories, id: \.self) { cat in
                            Text(cat).tag(String?.some(cat))
                        }
                    }
                }
            } label: {
                Image(systemName: selectedCategory != nil ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle")
                    .font(.title2)
                    .foregroundColor(DSColor.brand)
            }

            Button {
                showAddProductSheet = true
            } label: {
                Image(systemName: "plus.circle.fill")
                    .font(.title2)
                    .foregroundColor(DSColor.brand)
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
    @State private var category = ""
    @State private var size = ""
    @State private var photoItem: PhotosPickerItem?
    @State private var selectedImageData: Data?
    @State private var selectedImageContentType: String?
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

                    TextField("Categoria (Opcional)", text: $category)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)

                    TextField("Tamanho (Opcional)", text: $size)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                }

                Section(header: Text("Imagem (Opcional)")) {
                    PhotosPicker(selection: $photoItem, matching: .images) {
                        Label("Selecionar Foto", systemImage: "photo.badge.plus")
                    }
                    .onChange(of: photoItem) { loadPhoto(from: $1) }

                    if let data = selectedImageData, let uiImage = UIImage(data: data) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .scaledToFit()
                            .frame(maxHeight: 200)
                            .cornerRadius(8)
                    }
                }
            }
            .navigationTitle("Novo Produto")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Salvar") { submit() }
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

    private func loadPhoto(from item: PhotosPickerItem?) {
        guard let item else { return }
        Task {
            if let data = try? await item.loadTransferable(type: Data.self) {
                selectedImageData = data
                let contentType = item.supportedContentTypes.first?.preferredMIMEType ?? "image/jpeg"
                selectedImageContentType = contentType
            }
        }
    }

    private func submit() {
        isSubmitting = true

        let normalizedPrice = priceString.replacingOccurrences(of: ",", with: ".")
        let priceValue = Double(normalizedPrice) ?? 0.0
        let priceInCents = Double(Int(round(priceValue * 100)))

        Task {
            let success = await viewModel.addProduct(
                name: name,
                description: description,
                price: priceInCents,
                category: category.isEmpty ? nil : category,
                size: size.isEmpty ? nil : size,
                imageData: selectedImageData,
                imageContentType: selectedImageContentType
            )
            isSubmitting = false
            if success { dismiss() }
        }
    }
}

// MARK: - Edit Product Sheet

struct EditProductView: View {
    @Environment(\.dismiss) private var dismiss
    let product: ProductResponse
    @ObservedObject var viewModel: ProductsViewModel

    @State private var name: String
    @State private var description: String
    @State private var priceString: String
    @State private var category: String
    @State private var size: String
    @State private var photoItem: PhotosPickerItem?
    @State private var selectedImageData: Data?
    @State private var selectedImageContentType: String?
    @State private var existingImageURL: String?
    @State private var isSubmitting = false


    init(product: ProductResponse, viewModel: ProductsViewModel) {
        self.product = product
        self.viewModel = viewModel
        _name = State(initialValue: product.name)
        _description = State(initialValue: product.description ?? "")
        let reais = Double(product.price) / 100.0
        _priceString = State(initialValue: String(format: "%.2f", reais).replacingOccurrences(of: ".", with: ","))
        _category = State(initialValue: product.category ?? "")
        _size = State(initialValue: product.size ?? "")
        _existingImageURL = State(initialValue: product.image)
    }

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

                    TextField("Categoria (Opcional)", text: $category)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)

                    TextField("Tamanho (Opcional)", text: $size)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                }

                Section(header: Text("Imagem")) {
                    PhotosPicker(selection: $photoItem, matching: .images) {
                        Label(selectedImageData != nil ? "Trocar Foto" : "Selecionar Foto", systemImage: "photo.badge.plus")
                    }
                    .onChange(of: photoItem) { loadPhoto(from: $1) }

                    if let data = selectedImageData, let uiImage = UIImage(data: data) {
                        ZStack(alignment: .topTrailing) {
                            Image(uiImage: uiImage)
                                .resizable()
                                .scaledToFit()
                                .frame(maxHeight: 200)
                                .cornerRadius(8)
                            Button {
                                selectedImageData = nil
                                selectedImageContentType = nil
                                photoItem = nil
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.title2)
                                    .foregroundStyle(.white, DSColor.brand)
                            }
                            .padding(6)
                        }
                    } else if let imageURL = existingImageURL, let url = URL(string: imageURL) {
                        ZStack(alignment: .topTrailing) {
                            AsyncImage(url: url) { phase in
                                switch phase {
                                case .success(let image):
                                    image.resizable().scaledToFit().frame(maxHeight: 200).cornerRadius(8)
                                case .failure:
                                    EmptyView()
                                default:
                                    ProgressView()
                                }
                            }
                            Button {
                                Task { await deleteExistingImage() }
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.title2)
                                    .foregroundStyle(.white, DSColor.brand)
                            }
                            .padding(6)
                        }
                    }
                }
            }
            .navigationTitle("Editar Produto")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Salvar") { submit() }
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

    private func deleteExistingImage() async {
        isSubmitting = true
        let success = await viewModel.deleteProductImage(id: product.id)
        isSubmitting = false
        if success { existingImageURL = nil }
    }

    private func loadPhoto(from item: PhotosPickerItem?) {
        guard let item else { return }
        Task {
            if let data = try? await item.loadTransferable(type: Data.self) {
                selectedImageData = data
                let contentType = item.supportedContentTypes.first?.preferredMIMEType ?? "image/jpeg"
                selectedImageContentType = contentType
            }
        }
    }

    private func submit() {
        isSubmitting = true

        let normalizedPrice = priceString.replacingOccurrences(of: ",", with: ".")
        let priceValue = Double(normalizedPrice) ?? 0.0
        let priceInCents = Double(Int(round(priceValue * 100)))

        Task {
            let success = await viewModel.updateProduct(
                id: product.id,
                name: name,
                description: description,
                price: priceInCents,
                category: category.isEmpty ? nil : category,
                size: size.isEmpty ? nil : size,
                imageData: selectedImageData,
                imageContentType: selectedImageContentType
            )
            isSubmitting = false
            if success { dismiss() }
        }
    }
}

// MARK: - Product Card

struct ProductCard: View {
    let product: ProductResponse

    private var formattedPrice: String {
        Formatters.brl(product.price)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ZStack(alignment: .topTrailing) {
                productImage
                    .aspectRatio(1, contentMode: .fill)
                    .frame(maxWidth: .infinity)
                    .clipped()
                    .cornerRadius(10)

                if product.hasRecipe {
                    Image(systemName: "list.bullet.clipboard.fill")
                        .font(.caption)
                        .foregroundColor(.white)
                        .padding(6)
                        .background(DSColor.brand)
                        .clipShape(Circle())
                        .padding(6)
                }
            }

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
                .lineLimit(2)

                HStack(spacing: 6) {
                    if let category = product.category, !category.isEmpty {
                        Text(category)
                            .font(.caption2)
                            .fontWeight(.medium)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(DSColor.brand.opacity(0.1))
                            .foregroundColor(DSColor.brand)
                            .cornerRadius(6)
                    }
                    if let size = product.size, !size.isEmpty {
                        Text(size)
                            .font(.caption2)
                            .fontWeight(.medium)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Color.blue.opacity(0.1))
                            .foregroundColor(.blue)
                            .cornerRadius(6)
                    }
                }

                if let desc = product.description, !desc.isEmpty {
                    Text(desc)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }

                Text(formattedPrice)
                    .font(.system(size: 14, weight: .semibold, design: .monospaced))
                    .foregroundColor(DSColor.brand)
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
    }

    @ViewBuilder
    private var productImage: some View {
        if let imageURL = product.image, let url = URL(string: imageURL) {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    image.resizable().scaledToFill()
                default:
                    fallbackImage
                }
            }
        } else {
            fallbackImage
        }
    }

    private var fallbackImage: some View {
        ZStack {
            DSColor.brandSoft
            Image(systemName: "shippingbox.fill")
                .font(.title2)
                .foregroundColor(DSColor.brand)
        }
    }
}
