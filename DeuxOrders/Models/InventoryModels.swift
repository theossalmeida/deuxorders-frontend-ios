import Foundation

// MARK: - Measure Unit

enum MeasureUnit: Codable, CaseIterable, Hashable {
    case ml, g, u

    var label: String {
        switch self {
        case .ml: return "ML"
        case .g: return "G"
        case .u: return "U"
        }
    }

    // Decode from string ("ML", "G", "U") or numeric (1, 2, 3)
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let str = try? container.decode(String.self) {
            switch str.uppercased() {
            case "ML": self = .ml
            case "G": self = .g
            case "U": self = .u
            default: self = .u
            }
        } else if let num = try? container.decode(Int.self) {
            switch num {
            case 1: self = .ml
            case 2: self = .g
            case 3: self = .u
            default: self = .u
            }
        } else {
            self = .u
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(intValue)
    }

    var intValue: Int {
        switch self {
        case .ml: return 1
        case .g: return 2
        case .u: return 3
        }
    }
}

// MARK: - Material

struct Material: Codable, Identifiable {
    let id: String
    let name: String
    let quantity: Double
    let unitCost: Int
    let measureUnit: MeasureUnit
    var status: Bool
    let createdAt: Date?
    let updatedAt: Date?
}

struct MaterialsResponse: Decodable {
    let items: [Material]
    let totalCount: Int
    let pageNumber: Int
    let pageSize: Int
}

struct MaterialDropdownItem: Decodable, Identifiable {
    let id: String
    let name: String
    let measureUnit: MeasureUnit
}

// MARK: - Create / Update / Restock

struct CreateMaterialInput: Codable {
    let name: String
    let quantity: Double
    let totalCost: Int
    let measureUnit: Int
}

struct UpdateMaterialInput: Codable {
    let name: String
    let measureUnit: Int
}

struct RestockInput: Codable {
    let quantity: Double
    let totalCost: Int
}
