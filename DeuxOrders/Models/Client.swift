//
//  Client.swift
//  DeuxOrders
//
//  Created by Theo on 05/03/26.
//


struct Client: Codable, Identifiable {
    let id: String
    let name: String
    let mobile: String?
}
