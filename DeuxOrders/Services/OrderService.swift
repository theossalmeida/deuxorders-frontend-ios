import Foundation

struct QuantityUpdateInput: Codable {
    let increment: Int
}

struct DeleteReferenceRequest: Codable {
    let objectKey: String
}

struct UnpayRequest: Codable {
    let reason: String
}

struct PresignedUploadRequest: Codable {
    let fileName: String
    let contentType: String
}

struct PresignedUploadResponse: Codable {
    let uploadUrl: String
    let objectKey: String
}

class OrderService {
    private let api = APIClient.shared

    func fetchOrders() async throws -> [Order] {
        let response: OrderResponse = try await api.get("orders/all?page=1&size=100")
        return response.items.sorted { $0.deliveryDate > $1.deliveryDate }
    }

    func createOrder(input: OrderInput) async throws {
        try await api.post("orders/new", body: input)
    }

    func updateOrder(id: String, input: UpdateOrderRequest) async throws {
        try await api.put("orders/\(id)", body: input)
    }

    func completeOrder(id: String) async throws {
        try await api.patch("orders/\(id)/complete")
    }

    func cancelOrder(id: String) async throws {
        try await api.patch("orders/\(id)/cancel")
    }

    func payOrder(id: String) async throws {
        try await api.patch("orders/\(id)/pay")
    }

    func unpayOrder(id: String, reason: String) async throws {
        try await api.patch("orders/\(id)/unpay", body: UnpayRequest(reason: reason))
    }

    func cancelOrderItem(orderId: String, productId: String) async throws {
        try await api.patch("orders/\(orderId)/items/\(productId)/cancel")
    }

    func updateOrderItemQuantity(orderId: String, productId: String, increment: Int) async throws {
        try await api.patch("orders/\(orderId)/items/\(productId)/quantity", body: QuantityUpdateInput(increment: increment))
    }

    func deleteOrder(id: String) async throws {
        try await api.delete("orders/\(id)")
    }

    func deleteReference(orderId: String, objectKey: String) async throws {
        try await api.delete("orders/\(orderId)/references", body: DeleteReferenceRequest(objectKey: objectKey))
    }

    func getPresignedUrl(fileName: String, contentType: String) async throws -> PresignedUploadResponse {
        try await api.post("orders/references/presigned-url", body: PresignedUploadRequest(fileName: fileName, contentType: contentType))
    }

    func uploadImage(to presignedUrl: String, data: Data, contentType: String) async throws {
        try await api.uploadRaw(to: presignedUrl, data: data, contentType: contentType)
    }

    func fetchClients() async throws -> [Client] {
        try await api.get("clients/dropdown?status=true")
    }

    func fetchProducts() async throws -> [ProductResponse] {
        let response: ProductListResponse = try await api.get("products/all?page=1&size=100&status=true")
        return response.items
    }
}
