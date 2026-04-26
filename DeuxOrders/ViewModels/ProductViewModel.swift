//
//  ProductViewModel.swift
//  DeuxOrders
//
//  Created by Theo on 11/03/26.
//

import Foundation
import Combine

@MainActor
class ProductsViewModel: ObservableObject {
    @Published var products: [ProductResponse] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let productService: ProductService

    init(productService: ProductService? = nil) {
        self.productService = productService ?? ProductService()
    }

    func loadProducts() async {
        isLoading = true
        defer { isLoading = false }

        do {
            self.products = try await productService.fetchProducts()
            self.errorMessage = nil
        } catch {
            self.errorMessage = "Falha ao carregar a lista de produtos."
        }
    }

    func addProduct(name: String, description: String, price: Double, category: String? = nil, size: String? = nil, imageData: Data? = nil, imageContentType: String? = nil) async -> Bool {
        let cleanedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanedDesc = description.trimmingCharacters(in: .whitespacesAndNewlines)
        let finalDesc = cleanedDesc.isEmpty ? nil : cleanedDesc
        let finalCategory = category?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased().nilIfEmpty
        let finalSize = size?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased().nilIfEmpty

        do {
            try await productService.createProduct(name: cleanedName, description: finalDesc, price: price, category: finalCategory, size: finalSize, imageData: imageData, imageContentType: imageContentType)
            await loadProducts()
            return true
        } catch {
            self.errorMessage = "Falha ao criar o produto. Verifique a conexão."
            return false
        }
    }

    func updateProduct(id: String, name: String, description: String, price: Double, category: String? = nil, size: String? = nil, imageData: Data? = nil, imageContentType: String? = nil) async -> Bool {
        let cleanedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanedDesc = description.trimmingCharacters(in: .whitespacesAndNewlines)
        let finalDesc = cleanedDesc.isEmpty ? nil : cleanedDesc
        let finalCategory = category?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased().nilIfEmpty
        let finalSize = size?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased().nilIfEmpty

        do {
            try await productService.updateProduct(id: id, name: cleanedName, description: finalDesc, price: price, category: finalCategory, size: finalSize, imageData: imageData, imageContentType: imageContentType)
            await loadProducts()
            return true
        } catch {
            self.errorMessage = "Falha ao atualizar o produto. Verifique a conexão."
            return false
        }
    }

    func deleteProductImage(id: String) async -> Bool {
        do {
            try await productService.deleteProductImage(id: id)
            await loadProducts()
            return true
        } catch {
            self.errorMessage = "Falha ao remover a imagem."
            return false
        }
    }

    func deleteProduct(id: String) async {
        do {
            try await productService.deleteProduct(id: id)
            products.removeAll { $0.id == id }
        } catch {
            self.errorMessage = "Este produto possui pedidos associados e não pode ser excluído. Sugerimos que seja desativado."
        }
    }

    func deactivateProduct(id: String) async {
        guard let index = products.firstIndex(where: { $0.id == id }) else { return }

        let originalState = products[index].status
        products[index].status = false

        do {
            try await productService.deactivateProduct(id: id)
        } catch {
            products[index].status = originalState
            self.errorMessage = "Falha ao comunicar desativação ao servidor."
        }
    }

    func activateProduct(id: String) async {
        guard let index = products.firstIndex(where: { $0.id == id }) else { return }

        let originalState = products[index].status
        products[index].status = true

        do {
            try await productService.activateProduct(id: id)
        } catch {
            products[index].status = originalState
            self.errorMessage = "Falha ao comunicar ativação ao servidor."
        }
    }

    func fetchRecipe(productId: String) async throws -> ProductRecipeResponse {
        try await productService.fetchRecipe(productId: productId)
    }

    func updateRecipe(productId: String, items: [ProductRecipeItemInput]) async -> Bool {
        do {
            try await productService.updateRecipe(productId: productId, items: items)
            await loadProducts()
            return true
        } catch {
            errorMessage = "Falha ao salvar receita."
            return false
        }
    }

    func fetchRecipeOptions(productId: String) async throws -> [ProductRecipeOptionResponse] {
        try await productService.fetchRecipeOptions(productId: productId)
    }

    func updateRecipeOption(
        productId: String,
        type: ProductRecipeOptionType,
        name: String,
        items: [ProductRecipeItemInput]
    ) async -> Bool {
        let cleanedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanedName.isEmpty else {
            errorMessage = "Informe o nome da opcao."
            return false
        }

        do {
            _ = try await productService.updateRecipeOption(productId: productId, type: type, name: cleanedName, items: items)
            await loadProducts()
            return true
        } catch {
            errorMessage = "Falha ao salvar opcao de receita."
            return false
        }
    }

    func fetchOrderOptions(productId: String) async -> ProductOrderOptionsResponse {
        do {
            return try await productService.fetchOrderOptions(productId: productId)
        } catch {
            return .fallback
        }
    }

    func fetchStats(productId: String, month: String) async throws -> ProductStats {
        try await productService.fetchStats(productId: productId, month: month)
    }
}

private extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}
