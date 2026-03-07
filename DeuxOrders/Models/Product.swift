//
//  Product.swift
//  DeuxOrders
//
//  Created by Theo on 05/03/26.
//


struct ProductResponse: Codable, Identifiable {
    let id: String
    let name: String
    let price: Double
    let status: Bool
}

struct Product: Codable {
    let name: String
    let descricao: String?
    let price: Double
}
