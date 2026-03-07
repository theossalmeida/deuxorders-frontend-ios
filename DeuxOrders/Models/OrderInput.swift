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

struct OrderItemInput: Codable {
    let productid: String
    let quantity: Int
    let unitprice: Int
}
