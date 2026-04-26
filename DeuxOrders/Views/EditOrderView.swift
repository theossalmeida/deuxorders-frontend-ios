//
//  EditOrderView.swift
//  DeuxOrders
//
//  Created by Theo on 09/03/26.
//

import SwiftUI

struct EditOrderView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var viewModel: OrdersViewModel
    let order: Order

    @FocusState private var isInputActive: Bool

    @State private var allClients: [Client] = []
    @State private var allProducts: [ProductResponse] = []

    @State private var selectedClientId: String
    @State private var deliveryDate: Date
    @State private var deliveryAddress: String

    // Tracks what the user changed in each existing item. Only changed items enter the payload.
    @State private var editedItems: [String: EditedItem] = [:]

    @State private var newItems: [OrderItemInput] = []

    @State private var selectedStatus: OrderStatus
    @State private var selectedProductId: String = ""
    @State private var quantity: String = "1"
    @State private var itemUnitPrice: String = ""
    @State private var itemMassa: String = ""
    @State private var itemSabor: String = ""
    @State private var itemObservation: String = ""

    @State private var currentReferences: [String]
    @State private var newReferenceImages: [UIImage] = []
    @State private var isDeleting = false
    @State private var showDeleteConfirmation = false
    @State private var isUpdating = false
    private var isAdmin: Bool { AppSession.isAdministrator }

    struct EditedItem {
        var quantity: Int
        var paidUnitPrice: Int
        var observation: String?
        var massa: String
        var sabor: String
    }

    init(viewModel: OrdersViewModel, order: Order) {
        self.viewModel = viewModel
        self.order = order
        _selectedClientId = State(initialValue: order.clientId)
        _deliveryDate = State(initialValue: order.deliveryDate)
        let addr = order.deliveryAddress ?? ""
        _deliveryAddress = State(initialValue: (addr.isEmpty || addr == "pickup") ? "Retirada" : addr)
        _selectedStatus = State(initialValue: order.status)

        var initial: [String: EditedItem] = [:]
        for item in order.items {
            initial[item.productId] = EditedItem(
                quantity: item.quantity,
                paidUnitPrice: item.paidUnitPrice,
                observation: item.observation,
                massa: item.massa ?? "",
                sabor: item.sabor ?? ""
            )
        }
        _editedItems = State(initialValue: initial)
        _currentReferences = State(initialValue: order.references ?? [])
    }

    private var totalOrderValue: Double {
        let existingTotal = order.items.reduce(0) { total, item in
            let qty = editedItems[item.productId]?.quantity ?? item.quantity
            let price = editedItems[item.productId]?.paidUnitPrice ?? item.paidUnitPrice
            return total + (price * qty)
        }
        let newTotal = newItems.reduce(0) { $0 + ($1.unitPrice * $1.quantity) }
        return Double(existingTotal + newTotal) / 100.0
    }

    var body: some View {
        Form {
            OrderBasicInfoSection(
                allClients: allClients,
                selectedClientId: $selectedClientId,
                deliveryDate: $deliveryDate,
                deliveryAddress: $deliveryAddress
            )
            Section("Status") {
                Picker("Status", selection: $selectedStatus) {
                    ForEach(OrderStatus.allCases, id: \.self) { status in
                        Text(status.localizedName).tag(status)
                    }
                }
            }
            existingItemsSection
            ReferenceImagesSection(
                selectedImages: $newReferenceImages,
                existingUrls: currentReferences,
                onDeleteExisting: { url in Task { await deleteReference(url: url) } }
            )
            AddItemFormSection(
                allProducts: allProducts,
                sectionTitle: "Adicionar Novos Itens",
                selectedProductId: $selectedProductId,
                quantity: $quantity,
                itemUnitPrice: $itemUnitPrice,
                itemMassa: $itemMassa,
                itemSabor: $itemSabor,
                itemObservation: $itemObservation,
                isInputActive: $isInputActive,
                items: newItems,
                onAdd: addNewItem,
                onDelete: { newItems.remove(atOffsets: $0) }
            )
            OrderTotalSection(totalOrderValue: totalOrderValue)
            if isAdmin {
                deleteSection
            }
        }
        .navigationTitle("Editar Pedido")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("OK") { isInputActive = false }
            }
            ToolbarItem(placement: .confirmationAction) {
                if isUpdating {
                    ProgressView()
                } else {
                    Button("Atualizar") {
                        Task { await handleUpdate() }
                    }
                    .disabled(selectedClientId.isEmpty || isUpdating)
                }
            }
        }
        .task { await loadData() }
        .alert("Excluir Pedido", isPresented: $showDeleteConfirmation) {
            Button("Cancelar", role: .cancel) { }
            Button("Excluir", role: .destructive) {
                Task { await handleDelete() }
            }
        } message: {
            Text("Tem certeza que deseja apagar permanentemente este pedido?")
        }
        .disabled(isUpdating || isDeleting)
    }
}

// MARK: - Sections

extension EditOrderView {

    private var existingItemsSection: some View {
        Section("Itens do Pedido (Existentes)") {
            if order.items.isEmpty {
                Text("Nenhum item existente.").foregroundColor(.secondary)
            } else {
                ForEach(order.items, id: \.productId) { item in
                    VStack(alignment: .leading, spacing: 8) {
                        Text(item.productName).font(.headline)
                        if let size = item.productSize, !size.isEmpty {
                            Text(size)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        HStack {
                            Text("Qtd:")
                            Stepper(
                                value: quantityBinding(for: item),
                                in: 1...999
                            ) {
                                Text("\(editedItems[item.productId]?.quantity ?? item.quantity)")
                            }
                            Spacer()
                            Text(formattedTotal(for: item))
                        }

                        TextField("Preço unit. (R$)", text: priceBinding(for: item))
                            .textFieldStyle(.roundedBorder)
                            .keyboardType(.decimalPad)
                            .focused($isInputActive)

                        if requiresMassaSabor(for: item) {
                            TextField("Massa", text: massaBinding(for: item))
                                .textFieldStyle(.roundedBorder)
                            TextField("Sabor", text: saborBinding(for: item))
                                .textFieldStyle(.roundedBorder)
                        }

                        if let obs = editedItems[item.productId]?.observation, !obs.isEmpty {
                            Text("Obs: \(obs)").font(.subheadline).foregroundColor(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        if !item.itemCanceled {
                            Button(role: .destructive) {
                                Task { await cancelItem(productId: item.productId) }
                            } label: {
                                Label("Cancelar", systemImage: "xmark.circle.fill")
                            }
                        }
                    }
                }
            }
        }
    }

    private var deleteSection: some View {
        Section {
            Button(role: .destructive) {
                showDeleteConfirmation = true
            } label: {
                HStack {
                    Spacer()
                    if isDeleting {
                        ProgressView()
                    } else {
                        Text("Deletar Pedido").fontWeight(.bold)
                    }
                    Spacer()
                }
            }
            .disabled(isDeleting)
        }
    }
}

// MARK: - Helpers e Actions

extension EditOrderView {

    private func quantityBinding(for item: OrderItem) -> Binding<Int> {
        Binding(
            get: { editedItems[item.productId]?.quantity ?? item.quantity },
            set: { newQty in
                editedItems[item.productId]?.quantity = newQty
            }
        )
    }

    private func formattedTotal(for item: OrderItem) -> String {
        let qty = editedItems[item.productId]?.quantity ?? item.quantity
        let price = editedItems[item.productId]?.paidUnitPrice ?? item.paidUnitPrice
        let totalValue = Double(qty * price) / 100.0
        return Formatters.currency.string(from: NSNumber(value: totalValue)) ?? "R$ 0,00"
    }

    private func priceBinding(for item: OrderItem) -> Binding<String> {
        Binding(
            get: {
                let cents = editedItems[item.productId]?.paidUnitPrice ?? item.paidUnitPrice
                return String(format: "%.2f", Double(cents) / 100.0)
            },
            set: { newValue in
                let cleaned = newValue.replacingOccurrences(of: ",", with: ".")
                if let price = Double(cleaned) {
                    editedItems[item.productId]?.paidUnitPrice = Int(round(price * 100))
                }
            }
        )
    }

    private func requiresMassaSabor(for item: OrderItem) -> Bool {
        if item.massa != nil || item.sabor != nil { return true }
        guard let product = allProducts.first(where: { $0.id == item.productId }) else { return false }
        let cat = product.category?.lowercased() ?? ""
        return cat == "bolo" || cat == "doce"
    }

    private func massaBinding(for item: OrderItem) -> Binding<String> {
        Binding(
            get: { editedItems[item.productId]?.massa ?? "" },
            set: { editedItems[item.productId]?.massa = $0 }
        )
    }

    private func saborBinding(for item: OrderItem) -> Binding<String> {
        Binding(
            get: { editedItems[item.productId]?.sabor ?? "" },
            set: { editedItems[item.productId]?.sabor = $0 }
        )
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

    private func addNewItem() {
        let cleanedPrice = itemUnitPrice.replacingOccurrences(of: ",", with: ".")
        guard let q = Int(quantity),
              let unitPrice = Double(cleanedPrice),
              !selectedProductId.isEmpty,
              q > 0,
              unitPrice >= 0 else { return }

        let unitPriceCents = Int(round(unitPrice * 100))
        newItems.append(OrderItemInput(
            productId: selectedProductId,
            quantity: q,
            unitPrice: unitPriceCents,
            observation: itemObservation.isEmpty ? nil : itemObservation,
            massa: itemMassa.isEmpty ? nil : itemMassa,
            sabor: itemSabor.isEmpty ? nil : itemSabor
        ))

        selectedProductId = ""
        quantity = "1"
        itemUnitPrice = ""
        itemMassa = ""
        itemSabor = ""
        itemObservation = ""
        isInputActive = false
    }

    private func handleUpdate() async {
        isUpdating = true

        let deliveryDateChanged = !Calendar.current.isDate(deliveryDate, equalTo: order.deliveryDate, toGranularity: .minute)
        let deliveryDatePayload: String? = deliveryDateChanged ? Formatters.iso8601.string(from: deliveryDate) : nil

        let statusChanged = selectedStatus != order.status
        let statusPayload: Int? = statusChanged ? selectedStatus.intValue : nil

        let normalizedAddress = deliveryAddress == "Retirada" ? "pickup" : deliveryAddress
        let originalAddress = (order.deliveryAddress ?? "pickup")
        let addressChanged = normalizedAddress != originalAddress
        let addressPayload: String? = addressChanged ? (normalizedAddress.isEmpty ? nil : normalizedAddress) : nil

        var itemsPayload: [UpdateOrderItemRequest] = order.items.compactMap { item in
            guard let edited = editedItems[item.productId] else { return nil }
            let quantityChanged = edited.quantity != item.quantity
            let priceChanged = edited.paidUnitPrice != item.paidUnitPrice
            let obsChanged = edited.observation != item.observation
            let massaChanged = edited.massa != (item.massa ?? "")
            let saborChanged = edited.sabor != (item.sabor ?? "")
            guard quantityChanged || priceChanged || obsChanged || massaChanged || saborChanged else { return nil }

            return UpdateOrderItemRequest(
                productId: item.productId,
                quantity: quantityChanged ? edited.quantity : nil,
                paidUnitPrice: priceChanged ? edited.paidUnitPrice : nil,
                observation: obsChanged ? edited.observation : nil,
                massa: massaChanged ? (edited.massa.isEmpty ? nil : edited.massa) : nil,
                sabor: saborChanged ? (edited.sabor.isEmpty ? nil : edited.sabor) : nil
            )
        }

        let newItemsPayload: [UpdateOrderItemRequest] = newItems.map { item in
            UpdateOrderItemRequest(
                productId: item.productId,
                quantity: item.quantity,
                paidUnitPrice: item.unitPrice,
                observation: item.observation,
                massa: item.massa,
                sabor: item.sabor
            )
        }
        itemsPayload.append(contentsOf: newItemsPayload)

        do {
            let newObjectKeys = try await uploadReferenceImages()
            let payload = UpdateOrderRequest(
                deliveryDate: deliveryDatePayload,
                status: statusPayload,
                deliveryAddress: addressPayload,
                items: itemsPayload.isEmpty ? nil : itemsPayload,
                references: newObjectKeys.isEmpty ? nil : newObjectKeys
            )
            let result = try await viewModel.orderService.updateOrder(id: order.id, input: payload)
            if !result.warnings.isEmpty {
                viewModel.errorMessage = result.warnings.joined(separator: "\n")
            }
            await viewModel.loadOrders()
            await MainActor.run { dismiss() }
        } catch {
            print("Erro na atualização: \(error)")
            isUpdating = false
        }
    }

    private func handleDelete() async {
        isDeleting = true
        do {
            try await viewModel.deleteOrder(id: order.id)
            await MainActor.run { dismiss() }
        } catch {
            print("Erro ao deletar: \(error)")
            isDeleting = false
        }
    }

    private func deleteReference(url: String) async {
        guard let key = objectKey(from: url) else { return }
        do {
            try await viewModel.orderService.deleteReference(orderId: order.id, objectKey: key)
            currentReferences.removeAll { $0 == url }
        } catch {
            print("Erro ao deletar referência: \(error)")
        }
    }

    private func objectKey(from urlString: String) -> String? {
        guard let url = URL(string: urlString),
              url.pathComponents.count > 2 else { return nil }
        return url.pathComponents.dropFirst(2).joined(separator: "/")
    }

    private func uploadReferenceImages() async throws -> [String] {
        var objectKeys: [String] = []
        for image in newReferenceImages {
            guard let data = image.jpegData(compressionQuality: 0.8) else { continue }
            let fileName = "\(UUID().uuidString).jpg"
            let response = try await viewModel.orderService.getPresignedUrl(fileName: fileName, contentType: "image/jpeg")
            try await viewModel.orderService.uploadImage(to: response.uploadUrl, data: data, contentType: "image/jpeg")
            objectKeys.append(response.objectKey)
        }
        return objectKeys
    }

    private func cancelItem(productId: String) async {
        do {
            try await viewModel.orderService.cancelOrderItem(orderId: order.id, productId: productId)
            await viewModel.loadOrders()
            await MainActor.run { dismiss() }
        } catch {
            print("Erro ao cancelar item: \(error)")
        }
    }
}
