import Foundation

struct OrderInput: Codable {
    let clientId: String
    let deliveryDate: String
    let deliveryAddress: String?
    let items: [OrderItemInput]
    let references: [String]?
}

struct OrderItemInput: Codable, Identifiable {
    var id = UUID()
    let productId: String
    let quantity: Int
    let unitPrice: Int
    let observation: String?
    let massa: String?
    let sabor: String?

    enum CodingKeys: String, CodingKey {
        case productId
        case quantity
        case unitPrice
        case observation
        case massa
        case sabor
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(productId, forKey: .productId)
        try container.encode(quantity, forKey: .quantity)
        try container.encode(unitPrice, forKey: .unitPrice)

        if let obs = observation {
            let cleanObs = obs.trimmingCharacters(in: .whitespacesAndNewlines)
            if !cleanObs.isEmpty {
                try container.encode(cleanObs, forKey: .observation)
            }
        }

        if let m = massa, !m.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            try container.encode(m, forKey: .massa)
        }
        if let s = sabor, !s.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            try container.encode(s, forKey: .sabor)
        }
    }
}
