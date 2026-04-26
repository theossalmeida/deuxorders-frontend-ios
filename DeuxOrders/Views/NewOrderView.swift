//
//  NewOrderView.swift
//  DeuxOrders
//
//  Created by Theo on 05/03/26.
//

import SwiftUI
import Combine

@MainActor
final class NewOrderState: ObservableObject {
    @Published var selectedClientId: String = ""
    @Published var deliveryDate: Date = Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date()
    @Published var deliveryAddress: String = "Retirada"
    @Published var items: [OrderItemInput] = []
    @Published var selectedProductId: String = ""
    @Published var quantity: String = "1"
    @Published var itemUnitPrice: String = ""
    @Published var itemMassa: String = ""
    @Published var itemSabor: String = ""
    @Published var itemObservation: String = ""
    @Published var referenceImages: [UIImage] = []

    func reset() {
        selectedClientId = ""
        deliveryDate = Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date()
        deliveryAddress = "Retirada"
        items = []
        selectedProductId = ""
        quantity = "1"
        itemUnitPrice = ""
        itemMassa = ""
        itemSabor = ""
        itemObservation = ""
        referenceImages = []
    }
}

struct NewOrderView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var viewModel: OrdersViewModel
    @ObservedObject var state: NewOrderState
    @FocusState private var isInputActive: Bool

    @State private var allClients: [Client] = []
    @State private var allProducts: [ProductResponse] = []

    private var totalOrderValue: Double {
        let totalCents = state.items.reduce(0) { $0 + ($1.unitPrice * $1.quantity) }
        return Double(totalCents) / 100.0
    }

    var body: some View {
        NavigationStack {
            Form {
                OrderBasicInfoSection(
                    allClients: allClients,
                    selectedClientId: $state.selectedClientId,
                    deliveryDate: $state.deliveryDate,
                    deliveryAddress: $state.deliveryAddress
                )
                AddItemFormSection(
                    allProducts: allProducts,
                    sectionTitle: "Itens do Pedido",
                    selectedProductId: $state.selectedProductId,
                    quantity: $state.quantity,
                    itemUnitPrice: $state.itemUnitPrice,
                    itemMassa: $state.itemMassa,
                    itemSabor: $state.itemSabor,
                    itemObservation: $state.itemObservation,
                    isInputActive: $isInputActive,
                    items: state.items,
                    onAdd: addItem,
                    onDelete: { state.items.remove(atOffsets: $0) }
                )
                ReferenceImagesSection(selectedImages: $state.referenceImages)
                OrderTotalSection(totalOrderValue: totalOrderValue)
            }
            .navigationTitle("Novo Pedido")
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("OK") { isInputActive = false }
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Salvar") { Task { await handleSave() } }
                        .disabled(state.items.isEmpty || state.selectedClientId.isEmpty)
                }
            }
            .task { await loadData() }
        }
    }

    private func loadData() async {
        do {
            async let fetchClients = viewModel.orderService.fetchClients()
            async let fetchProducts = viewModel.orderService.fetchProducts()
            let (clients, products) = try await (fetchClients, fetchProducts)
            await MainActor.run {
                self.allClients = clients
                self.allProducts = products
            }
        } catch {
            print("Erro ao carregar dados da API: \(error)")
        }
    }

    private func addItem() {
        let cleanedPrice = state.itemUnitPrice.replacingOccurrences(of: ",", with: ".")
        guard let q = Int(state.quantity),
              let unitPrice = Double(cleanedPrice),
              !state.selectedProductId.isEmpty,
              q > 0,
              unitPrice >= 0 else { return }

        let unitPriceCents = Int(round(unitPrice * 100))
        state.items.append(OrderItemInput(
            productId: state.selectedProductId,
            quantity: q,
            unitPrice: unitPriceCents,
            observation: state.itemObservation.isEmpty ? nil : state.itemObservation,
            massa: state.itemMassa.isEmpty ? nil : state.itemMassa,
            sabor: state.itemSabor.isEmpty ? nil : state.itemSabor
        ))

        state.selectedProductId = ""
        state.quantity = "1"
        state.itemUnitPrice = ""
        state.itemMassa = ""
        state.itemSabor = ""
        state.itemObservation = ""
        isInputActive = false
    }

    private func handleSave() async {
        do {
            let objectKeys = try await uploadReferenceImages()
            let finalInput = OrderInput(
                clientId: state.selectedClientId,
                deliveryDate: Formatters.iso8601.string(from: state.deliveryDate),
                deliveryAddress: state.deliveryAddress == "Retirada" ? "pickup" : (state.deliveryAddress.isEmpty ? nil : state.deliveryAddress),
                items: state.items,
                references: objectKeys.isEmpty ? nil : objectKeys
            )
            try await viewModel.orderService.createOrder(input: finalInput)
            await viewModel.loadOrders()
            await MainActor.run {
                state.reset()
                dismiss()
            }
        } catch {
            print("❌ Erro: \(error)")
        }
    }

    private func uploadReferenceImages() async throws -> [String] {
        var objectKeys: [String] = []
        for image in state.referenceImages {
            guard let data = image.jpegData(compressionQuality: 0.8) else { continue }
            let fileName = "\(UUID().uuidString).jpg"
            let response = try await viewModel.orderService.getPresignedUrl(fileName: fileName, contentType: "image/jpeg")
            try await viewModel.orderService.uploadImage(to: response.uploadUrl, data: data, contentType: "image/jpeg")
            objectKeys.append(response.objectKey)
        }
        return objectKeys
    }
}

struct OrderItemRow: View {
    let item: OrderItemInput
    let productName: String
    let productSize: String?

    var itemTotal: Double {
        let totalCents = item.unitPrice * item.quantity
        return Double(totalCents) / 100.0
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(productName).bold()
                    if let size = productSize, !size.isEmpty {
                        Text(size)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Text("\(item.quantity)x \(Formatters.currency.string(from: NSNumber(value: Double(item.unitPrice) / 100.0)) ?? "R$ 0,00")")
                        .font(.caption).foregroundColor(.secondary)
                }
                Spacer()
                Text(Formatters.currency.string(from: NSNumber(value: itemTotal)) ?? "R$ 0,00")
                    .fontWeight(.semibold)
            }

            if let massa = item.massa, !massa.isEmpty {
                Text("Massa: \(massa)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            if let sabor = item.sabor, !sabor.isEmpty {
                Text("Sabor: \(sabor)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            if let obs = item.observation, !obs.isEmpty {
                Text("Obs: \(obs)")
                    .font(.caption)
                    .italic()
                    .foregroundColor(.secondary)
                    .padding(.top, 2)
            }
        }
        .padding(.vertical, 4)
    }
}
