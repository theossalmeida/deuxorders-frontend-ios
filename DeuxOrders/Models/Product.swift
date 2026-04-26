import Foundation

struct ProductResponse: Codable, Identifiable {
    let id: String
    let name: String
    let price: Double
    var status: Bool
    let description: String?
    let image: String?
    let category: String?
    let size: String?
    let hasRecipe: Bool?

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(String.self, forKey: .id)
        self.name = try container.decode(String.self, forKey: .name)
        self.price = try container.decode(Double.self, forKey: .price)
        self.status = try container.decodeIfPresent(Bool.self, forKey: .status) ?? true
        self.description = try container.decodeIfPresent(String.self, forKey: .description)
        self.image = try container.decodeIfPresent(String.self, forKey: .image)
        self.category = try container.decodeIfPresent(String.self, forKey: .category)
        self.size = try container.decodeIfPresent(String.self, forKey: .size)
        self.hasRecipe = try container.decodeIfPresent(Bool.self, forKey: .hasRecipe)
    }
}
