//
//  ClientInput.swift
//  DeuxOrders
//
//  Created by Theo on 11/03/26.
//

import Foundation

struct ClientInput: Codable {
    let name: String
    let mobile: String?
    let status: Bool?

    init(name: String, mobile: String?, status: Bool? = nil) {
        self.name = name
        self.mobile = mobile
        self.status = status
    }
}
