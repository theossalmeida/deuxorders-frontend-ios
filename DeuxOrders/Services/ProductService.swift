import Foundation

class ProductService {
    private let api = APIClient.shared

    func fetchProducts() async throws -> [ProductResponse] {
        struct ProductsResponse: Decodable { let items: [ProductResponse] }
        let response: ProductsResponse = try await api.get("products/all?size=100")
        return response.items
    }

    func createProduct(name: String, description: String?, price: Double, category: String? = nil, size: String? = nil, imageData: Data? = nil, imageContentType: String? = nil) async throws {
        var fields: [(String, String)] = [
            ("Name", name),
            ("Price", String(Int(price)))
        ]
        if let description { fields.append(("Description", description)) }
        if let category { fields.append(("Category", category)) }
        if let size { fields.append(("Size", size)) }

        let ext = imageContentType?.contains("png") == true ? "png" : "jpg"

        try await api.multipart(
            endpoint: "products/new",
            method: "POST",
            fields: fields,
            fileField: imageData != nil ? "Image" : nil,
            fileName: imageData != nil ? "product.\(ext)" : nil,
            fileData: imageData,
            fileContentType: imageContentType
        )
    }

    func updateProduct(id: String, name: String, description: String?, price: Double, category: String? = nil, size: String? = nil, imageData: Data? = nil, imageContentType: String? = nil) async throws {
        var fields: [(String, String)] = [
            ("Name", name),
            ("Price", String(Int(price)))
        ]
        if let description { fields.append(("Description", description)) }
        if let category { fields.append(("Category", category)) }
        if let size { fields.append(("Size", size)) }

        let ext = imageContentType?.contains("png") == true ? "png" : "jpg"

        try await api.multipart(
            endpoint: "products/\(id)",
            method: "PUT",
            fields: fields,
            fileField: imageData != nil ? "Image" : nil,
            fileName: imageData != nil ? "product.\(ext)" : nil,
            fileData: imageData,
            fileContentType: imageContentType
        )
    }

    func deleteProduct(id: String) async throws {
        try await api.delete("products/\(id)")
    }

    func deactivateProduct(id: String) async throws {
        try await api.patch("products/\(id)/inactive")
    }

    func activateProduct(id: String) async throws {
        try await api.patch("products/\(id)/active")
    }

    func deleteProductImage(id: String) async throws {
        try await api.delete("products/\(id)/image")
    }
}
