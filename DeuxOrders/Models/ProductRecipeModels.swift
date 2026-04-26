import Foundation

enum ProductRecipeOptionType: String, Codable, CaseIterable, Identifiable {
    case dough = "Dough"
    case filling = "Filling"
    case flavor = "Flavor"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .dough: return "Massa"
        case .filling: return "Recheio"
        case .flavor: return "Sabor"
        }
    }

    var intValue: Int {
        switch self {
        case .dough: return 1
        case .filling: return 2
        case .flavor: return 3
        }
    }
}

struct ProductRecipeItem: Codable, Identifiable, Hashable {
    var id: String { materialId }
    let materialId: String
    let materialName: String?
    let quantity: Double
    let measureUnit: MeasureUnit?
}

struct ProductRecipeResponse: Decodable {
    let hasRecipe: Bool
    let items: [ProductRecipeItem]
}

struct ProductRecipeOptionResponse: Decodable, Identifiable {
    let id: String
    let type: ProductRecipeOptionType
    let name: String
    let hasRecipe: Bool
    let items: [ProductRecipeItem]
}

struct ProductRecipeOptionsResponse: Decodable {
    let options: [ProductRecipeOptionResponse]
}

struct ProductRecipeItemInput: Codable, Identifiable, Hashable {
    var id: String { materialId }
    let materialId: String
    var quantity: Double
}

struct UpdateProductRecipeRequest: Codable {
    let items: [ProductRecipeItemInput]
}

struct UpdateProductRecipeOptionRequest: Codable {
    let type: ProductRecipeOptionType
    let name: String
    let items: [ProductRecipeItemInput]
}

struct ProductOrderOptionsResponse: Decodable {
    let cakeDoughs: [String]
    let cakeFillings: [String]
    let brigadeiroFlavors: [String]
    let cookieFlavors: [String]

    static let fallback = ProductOrderOptionsResponse(
        cakeDoughs: ["Baunilha", "Red Velvet", "Chocolate", "Limao", "Caramelo"],
        cakeFillings: ["brulee", "branco", "doce de leite", "limao", "beijinho", "chocolate", "cream cheese frosting"],
        brigadeiroFlavors: ["chocolate", "brulee", "beijinho", "limao", "churros", "casadinho"],
        cookieFlavors: ["churros", "cacau", "tradicional", "brookie", "caramelo salgado"]
    )

    func names(for type: ProductRecipeOptionType) -> [String] {
        switch type {
        case .dough:
            return cakeDoughs
        case .filling:
            return cakeFillings + brigadeiroFlavors
        case .flavor:
            return brigadeiroFlavors + cookieFlavors
        }
    }
}
