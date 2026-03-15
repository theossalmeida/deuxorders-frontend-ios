//
//  NewOrderView.swift
//  DeuxOrders
//
//  Created by Theo on 05/03/26.
//

import SwiftUI

enum Formatters {
    static let currency: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = Locale(identifier: "pt_BR")
        return formatter
    }()

    static let iso8601: ISO8601DateFormatter = {
        return ISO8601DateFormatter()
    }()
}

struct NewOrderView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var viewModel: OrdersViewModel
    @FocusState private var isInputActive: Bool

    @State private var allClients: [Client] = []
    @State private var allProducts: [ProductResponse] = []
    @State private var selectedClientId: String = ""
    @State private var deliveryDate = Date()
    @State private var items: [OrderItemInput] = []

    @State private var selectedProductId: String = ""
    @State private var quantity: String = "1"
    @State private var itemTotalPaid: String = ""
    @State private var itemObservation: String = ""
    @State private var referenceImages: [UIImage] = []

    private var totalOrderValue: Double {
        let totalCents = items.reduce(0) { $0 + ($1.unitprice * $1.quantity) }
        return Double(totalCents) / 100.0
    }

    var body: some View {
        NavigationStack {
            Form {
                OrderBasicInfoSection(
                    allClients: allClients,
                    selectedClientId: $selectedClientId,
                    deliveryDate: $deliveryDate
                )
                AddItemFormSection(
                    allProducts: allProducts,
                    sectionTitle: "Itens do Pedido",
                    selectedProductId: $selectedProductId,
                    quantity: $quantity,
                    itemTotalPaid: $itemTotalPaid,
                    itemObservation: $itemObservation,
                    isInputActive: $isInputActive,
                    items: items,
                    onAdd: addItem,
                    onDelete: { items.remove(atOffsets: $0) }
                )
                ReferenceImagesSection(selectedImages: $referenceImages)
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
                        .disabled(items.isEmpty || selectedClientId.isEmpty)
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
        let cleanedTotal = itemTotalPaid.replacingOccurrences(of: ",", with: ".")
        guard let q = Int(quantity),
              let total = Double(cleanedTotal),
              !selectedProductId.isEmpty,
              q > 0 else { return }

        let unitPriceCents = Int(round((total / Double(q)) * 100))
        items.append(OrderItemInput(
            productid: selectedProductId,
            quantity: q,
            unitprice: unitPriceCents,
            observation: itemObservation.isEmpty ? nil : itemObservation
        ))

        selectedProductId = ""
        quantity = "1"
        itemTotalPaid = ""
        itemObservation = ""
        isInputActive = false
    }

    private func handleSave() async {
        do {
            let objectKeys = try await uploadReferenceImages()
            let finalInput = OrderInput(
                clientid: selectedClientId,
                deliverydate: Formatters.iso8601.string(from: deliveryDate),
                items: items,
                references: objectKeys.isEmpty ? nil : objectKeys
            )
            try await viewModel.orderService.createOrder(input: finalInput)
            await viewModel.loadOrders()
            await MainActor.run { dismiss() }
        } catch {
            print("❌ Erro: \(error)")
        }
    }

    private func uploadReferenceImages() async throws -> [String] {
        var objectKeys: [String] = []
        for image in referenceImages {
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

    var itemTotal: Double {
        let totalCents = item.unitprice * item.quantity
        return Double(totalCents) / 100.0
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                VStack(alignment: .leading) {
                    Text(productName).bold()
                    Text("\(item.quantity)x \(Formatters.currency.string(from: NSNumber(value: Double(item.unitprice) / 100.0)) ?? "R$ 0,00")")
                        .font(.caption).foregroundColor(.secondary)
                }
                Spacer()
                Text(Formatters.currency.string(from: NSNumber(value: itemTotal)) ?? "R$ 0,00")
                    .fontWeight(.semibold)
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
