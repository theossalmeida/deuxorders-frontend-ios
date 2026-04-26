import Foundation

struct Client: Codable, Identifiable {
    let id: String
    let name: String
    let mobile: String?
    var status: Bool

    enum CodingKeys: String, CodingKey {
        case id, name, mobile, status, isActive
    }

    init(id: String, name: String, mobile: String?, status: Bool) {
        self.id = id
        self.name = name
        self.mobile = mobile
        self.status = status
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(String.self, forKey: .id)
        self.name = try container.decode(String.self, forKey: .name)
        self.mobile = try container.decodeIfPresent(String.self, forKey: .mobile)
        // Backend may send "status" or legacy "isActive"
        if let s = try container.decodeIfPresent(Bool.self, forKey: .status) {
            self.status = s
        } else {
            self.status = try container.decodeIfPresent(Bool.self, forKey: .isActive) ?? true
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encodeIfPresent(mobile, forKey: .mobile)
        try container.encode(status, forKey: .status)
    }
}

// MARK: - Client Detail (with stats and order history)

struct ClientStats: Decodable {
    let totalOrders: Int
    let totalSpent: Int
    let lastOrderDate: String?

    enum CodingKeys: String, CodingKey {
        case totalOrders, totalSpent, lastOrderDate
    }
}

struct ClientOrder: Decodable, Identifiable {
    let id: String
    let deliveryDate: Date
    let status: OrderStatus
    let totalPaid: Int
    let totalValue: Int

    enum CodingKeys: String, CodingKey {
        case id, deliveryDate, status, totalPaid, totalValue
    }
}

struct ClientDetail: Decodable {
    let id: String
    let name: String
    let mobile: String?
    let status: Bool
    let stats: ClientStats
    let orders: ClientOrdersWrapper

    struct ClientOrdersWrapper: Decodable {
        let items: [ClientOrder]
    }
}
