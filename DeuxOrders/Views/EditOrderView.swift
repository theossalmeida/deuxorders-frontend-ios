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
    private let brandColor = Color(red: 88/255, green: 22/255, blue: 41/255)

    @State private var allClients: [Client] = []
    @State private var allProducts: [ProductResponse] = []
    
    @State private var selectedClientId: String = ""
    @State private var deliveryDate = Date()
    @State private var items: [OrderItemInput] = []
    
    @State private var selectedProductId: String = ""
    @State private var quantity: String = "1"
    @State private var itemTotalPaid: String = ""
    @State private var itemObservation: String = ""
    
    @State private var isDeleting = false
    @State private var showDeleteConfirmation = false

    init(viewModel: OrdersViewModel, order: Order) {
        self.viewModel = viewModel
        self.order = order
        
        _selectedClientId = State(initialValue: order.clientId)
        _deliveryDate = State(initialValue: order.deliveryDate)
        
        let mappedItems = order.items.map {
            OrderItemInput(
                productid: $0.productId,
                quantity: $0.quantity,
                unitprice: $0.paidUnitPrice,
                observation: $0.observation
            )
        }
        _items = State(initialValue: mappedItems)
    }

    private var totalOrderValue: Double {
        let totalCents = items.reduce(0) { $0 + ($1.unitprice * $1.quantity) }
        return Double(totalCents) / 100.0
    }

    var body: some View {
        Form {
            basicInfoSection
            itemsSection
            totalSection
            deleteSection
        }
        .navigationTitle("Editar Pedido")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("OK") { isInputActive = false }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Atualizar") { Task { await handleUpdate() } }
                    .disabled(items.isEmpty || selectedClientId.isEmpty)
            }
        }
        .task {
            await loadData()
        }
        .alert("Excluir Pedido", isPresented: $showDeleteConfirmation) {
            Button("Cancelar", role: .cancel) { }
            Button("Excluir", role: .destructive) {
                Task { await handleDelete() }
            }
        } message: {
            Text("Tem certeza que deseja apagar permanentemente este pedido?")
        }
    }
}

extension EditOrderView {
    
    private var basicInfoSection: some View {
        Section("Informações Básicas") {
            Picker("Cliente", selection: $selectedClientId) {
                Text("Selecione um cliente").tag(String(""))
                ForEach(allClients) { client in
                    Text(client.name).tag(client.id)
                }
            }
            DatePicker("Entrega", selection: $deliveryDate, displayedComponents: [.date, .hourAndMinute])
        }
    }
    
    private var itemsSection: some View {
        Section("Itens do Pedido") {
            VStack(spacing: 12) {
                Picker("Produto", selection: $selectedProductId) {
                    Text("Selecione o produto").tag(String(""))
                    ForEach(allProducts) { prod in
                        if prod.status {
                            Text(prod.name).tag(prod.id)
                        }
                    }
                }
                .pickerStyle(.menu)
                .onChange(of: selectedProductId) { _, newValue in
                    updateTotalPaid(for: newValue)
                }

                HStack {
                    TextField("Qtd", text: $quantity)
                        .keyboardType(.numberPad)
                        .textFieldStyle(.roundedBorder)
                        .focused($isInputActive)
                        .onChange(of: quantity) { _, _ in recalculateTotalPaid() }
                    
                    TextField("Total Pago", text: $itemTotalPaid)
                        .keyboardType(.decimalPad)
                        .textFieldStyle(.roundedBorder)
                        .focused($isInputActive)
                }
                
                HStack {
                    TextField("Observação (opcional)", text: $itemObservation)
                        .textFieldStyle(.roundedBorder)
                        .focused($isInputActive)
                    
                    Button(action: addItem) {
                        Image(systemName: "plus.circle.fill")
                            .font(.title)
                            .foregroundColor(brandColor)
                    }
                    .buttonStyle(.borderless)
                }
            }
            .padding(.vertical, 8)

            ForEach(items) { item in
                OrderItemRow(item: item, productName: getProductName(id: item.productid))
            }
            .onDelete(perform: { items.remove(atOffsets: $0) })
        }
    }
    
    private var totalSection: some View {
        Section {
            HStack {
                Text("Total do Pedido")
                Spacer()
                Text(Formatters.currency.string(from: NSNumber(value: totalOrderValue)) ?? "R$ 0,00")
                    .font(.headline)
                    .foregroundColor(brandColor)
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
                        Text("Deletar Pedido")
                            .fontWeight(.bold)
                    }
                    Spacer()
                }
            }
            .disabled(isDeleting)
        }
    }
}

extension EditOrderView {
    
    private func updateTotalPaid(for productId: String) {
        if let prod = allProducts.first(where: { $0.id == productId }), let q = Int(quantity) {
            let total = (Double(prod.price) / 100.0) * Double(q)
            itemTotalPaid = String(format: "%.2f", total)
        }
    }
    
    private func recalculateTotalPaid() {
        updateTotalPaid(for: selectedProductId)
    }
    
    private func getProductName(id: String) -> String {
        allProducts.first(where: { $0.id == id })?.name ?? "Produto Desconhecido"
    }

    func loadData() async {
        do {
            let clients = try await viewModel.orderService.fetchClients()
            let products = try await viewModel.orderService.fetchProducts()
            await MainActor.run {
                self.allClients = clients
                self.allProducts = products
            }
        } catch {
            print("Erro ao carregar dados da API: \(error)")
        }
    }

    func addItem() {
        let cleanedTotal = itemTotalPaid.replacingOccurrences(of: ",", with: ".")
        
        if let q = Int(quantity),
           let total = Double(cleanedTotal),
           !selectedProductId.isEmpty,
           q > 0 {
            
            let rawUnitPrice = total / Double(q)
            let unitPriceCents = Int(round(rawUnitPrice * 100))
            
            let newItem = OrderItemInput(
                productid: selectedProductId,
                quantity: q,
                unitprice: unitPriceCents,
                observation: itemObservation.isEmpty ? nil : itemObservation
            )
            
            items.append(newItem)
            
            selectedProductId = ""
            quantity = "1"
            itemTotalPaid = ""
            itemObservation = ""
            isInputActive = false
        }
    }

    func handleUpdate() async {
        let finalInput = OrderInput(
            clientid: selectedClientId,
            deliverydate: Formatters.iso8601.string(from: deliveryDate),
            items: items
        )
        
        do {
            try await viewModel.orderService.updateOrder(id: order.id, input: finalInput)
            await viewModel.loadOrders()
            await MainActor.run { dismiss() }
        } catch {
            print("❌ Erro na atualização: \(error)")
        }
    }
    
    func handleDelete() async {
        isDeleting = true
        do {
            try await viewModel.deleteOrder(id: order.id)
            await MainActor.run { dismiss() }
        } catch {
            print("❌ Erro ao deletar: \(error)")
            isDeleting = false
        }
    }
}
