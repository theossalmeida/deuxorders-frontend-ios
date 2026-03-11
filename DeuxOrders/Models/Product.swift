//
//  Product.swift
//  DeuxOrders
//

import Foundation

struct ProductResponse: Codable, Identifiable {
    let id: String
    let name: String
    let price: Double
    var status: Bool
    let description: String?
    
    enum CodingKeys: String, CodingKey {
        case id, name, price, status
        case description = "descricao" // Maps bad backend naming to clean code property
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(String.self, forKey: .id)
        self.name = try container.decode(String.self, forKey: .name)
        self.price = try container.decode(Double.self, forKey: .price)
        self.status = try container.decodeIfPresent(Bool.self, forKey: .status) ?? true
        self.description = try container.decodeIfPresent(String.self, forKey: .description)
    }
}

struct ProductInput: Codable {
    let name: String
    let descricao: String?
    let price: Double
}
