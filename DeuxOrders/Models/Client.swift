//
//  Client.swift
//  DeuxOrders
//
//  Created by Theo on 05/03/26.
//

import Foundation

struct Client: Codable, Identifiable {
    let id: String
    let name: String
    let mobile: String?
    var isActive: Bool
    
    enum CodingKeys: String, CodingKey {
        case id, name, mobile, isActive
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(String.self, forKey: .id)
        self.name = try container.decode(String.self, forKey: .name)
        self.mobile = try container.decodeIfPresent(String.self, forKey: .mobile)
        self.isActive = try container.decodeIfPresent(Bool.self, forKey: .isActive) ?? true
    }
}
