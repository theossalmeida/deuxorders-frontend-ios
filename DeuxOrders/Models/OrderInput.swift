//
//  OrderInput.swift
//  DeuxOrders
//
//  Created by Theo on 05/03/26.
//

import Foundation

struct OrderInput: Codable {
    let clientid: String
    let deliverydate: String
    let items: [OrderItemInput]
}

struct OrderItemInput: Codable, Identifiable {
    var id = UUID()
    let productid: String
    let quantity: Int
    let unitprice: Int
    let observation: String?
    
    enum CodingKeys: String, CodingKey {
        case productid
        case quantity
        case unitprice
        case observation
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(productid, forKey: .productid)
        try container.encode(quantity, forKey: .quantity)
        try container.encode(unitprice, forKey: .unitprice)
        
        if let obs = observation {
            let cleanObs = obs.trimmingCharacters(in: .whitespacesAndNewlines)
            if !cleanObs.isEmpty {
                try container.encode(cleanObs, forKey: .observation)
            }
        }
    }
}
