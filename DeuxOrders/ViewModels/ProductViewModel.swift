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
    
    func addProduct(name: String, description: String, price: Double) async -> Bool {
        let cleanedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanedDesc = description.trimmingCharacters(in: .whitespacesAndNewlines)
        let finalDesc = cleanedDesc.isEmpty ? nil : cleanedDesc
        
        let input = ProductInput(name: cleanedName, descricao: finalDesc, price: price)
        
        do {
            try await productService.createProduct(input: input)
            await loadProducts()
            return true
        } catch {
            self.errorMessage = "Falha ao criar o produto. Verifique a conexão."
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
        products[index].status = false // Optimistic UI update
        
        do {
            try await productService.deactivateProduct(id: id)
        } catch {
            products[index].status = originalState // Rollback on failure
            self.errorMessage = "Falha ao comunicar desativação ao servidor."
        }
    }
}
