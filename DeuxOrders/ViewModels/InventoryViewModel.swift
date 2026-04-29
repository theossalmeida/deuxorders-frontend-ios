import Foundation
import Combine

@MainActor
class InventoryViewModel: ObservableObject {
    @Published var materials: [Material] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let service = InventoryService()

    func loadMaterials(search: String? = nil, status: Bool? = nil) async {
        isLoading = true
        defer { isLoading = false }
        do {
            materials = try await service.fetchMaterials(search: search, status: status)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func createMaterial(name: String, quantity: Double, totalCostReais: Double, measureUnit: MeasureUnit) async -> Bool {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty, quantity > 0, totalCostReais >= 0 else {
            errorMessage = "Preencha nome, quantidade e custo corretamente."
            return false
        }

        let input = CreateMaterialInput(
            name: trimmedName,
            quantity: quantity,
            totalCost: Int(round(totalCostReais * 100)),
            measureUnit: measureUnit.intValue
        )
        do {
            try await service.createMaterial(input: input)
            await loadMaterials()
            return true
        } catch {
            errorMessage = "Falha ao criar material."
            return false
        }
    }

    func updateMaterial(id: String, name: String, measureUnit: MeasureUnit) async -> Bool {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            errorMessage = "Informe o nome do material."
            return false
        }

        let input = UpdateMaterialInput(
            name: trimmedName,
            measureUnit: measureUnit.intValue
        )
        do {
            try await service.updateMaterial(id: id, input: input)
            await loadMaterials()
            return true
        } catch {
            errorMessage = "Falha ao atualizar material."
            return false
        }
    }

    func restockMaterial(id: String, quantity: Double, totalCostReais: Double) async -> Bool {
        guard quantity > 0, totalCostReais >= 0 else {
            errorMessage = "Informe uma quantidade positiva e um custo valido."
            return false
        }

        let input = RestockInput(
            quantity: quantity,
            totalCost: Int(round(totalCostReais * 100))
        )
        do {
            try await service.restockMaterial(id: id, input: input)
            await loadMaterials()
            return true
        } catch {
            errorMessage = "Falha ao reabastecer material."
            return false
        }
    }

    func activateMaterial(id: String) async {
        guard let index = materials.firstIndex(where: { $0.id == id }) else { return }
        let original = materials[index].status
        materials[index].status = true
        do {
            try await service.activateMaterial(id: id)
        } catch {
            materials[index].status = original
            errorMessage = "Falha ao ativar material."
        }
    }

    func deactivateMaterial(id: String) async {
        guard let index = materials.firstIndex(where: { $0.id == id }) else { return }
        let original = materials[index].status
        materials[index].status = false
        do {
            try await service.deactivateMaterial(id: id)
        } catch {
            materials[index].status = original
            errorMessage = "Falha ao desativar material."
        }
    }
}
