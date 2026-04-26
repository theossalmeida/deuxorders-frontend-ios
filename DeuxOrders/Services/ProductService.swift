import Foundation

class ProductService {
    private let api = APIClient.shared

    func fetchProducts() async throws -> [ProductResponse] {
        let response: ProductListResponse = try await api.get("products/all?page=1&size=100")
        return response.items
    }

    func createProduct(name: String, description: String?, price: Double, category: String? = nil, size: String? = nil, imageData: Data? = nil, imageContentType: String? = nil) async throws {
        let priceCents = Int(price.rounded())
        var fields: [(String, String)] = [
            ("Name", name),
            ("Price", String(priceCents))
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
        let priceCents = Int(price.rounded())
        var fields: [(String, String)] = [
            ("Name", name),
            ("Price", String(priceCents))
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

struct ProductListResponse: Decodable {
    let items: [ProductResponse]

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let items = try? container.decode([ProductResponse].self) {
            self.items = items
            return
        }

        let paginated = try container.decode(PaginatedProductResponse.self)
        self.items = paginated.items
    }
}

private struct PaginatedProductResponse: Decodable {
    let items: [ProductResponse]
}
