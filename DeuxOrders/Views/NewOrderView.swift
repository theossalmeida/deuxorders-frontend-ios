//
//  NewOrderView.swift
//  DeuxOrders
//
//  Created by Theo on 05/03/26.
//

import SwiftUI

// MARK: - Global Formatters (Performance Fix)
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

// MARK: - View Principal
struct NewOrderView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var viewModel: OrdersViewModel
    @FocusState private var isInputActive: Bool
    
    private let orderService = OrderService() // Architectural flaw: Move this to a ViewModel
    private let brandColor = Color(red: 88/255, green: 22/255, blue: 41/255)

    @State private var allClients: [Client] = []
    @State private var allProducts: [ProductResponse] = []
    @State private var selectedClientId: String = ""
    @State private var deliveryDate = Date()
    @State private var items: [OrderItemInput] = []
    @State private var selectedProductId: String = ""
    @State private var quantity: String = "1"
    @State private var itemTotalPaid: String = ""

    private var totalOrderValue: Double {
        let totalCents = items.reduce(0) { $0 + ($1.unitprice * $1.quantity) }
        return Double(totalCents) / 100.0
    }

    var body: some View {
        NavigationStack {
            Form {
                basicInfoSection
                itemsSection
                totalSection
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
            .task {
                await loadData()
            }
        }
    }
}

// MARK: - Subviews
extension NewOrderView {
    
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
                    
                    Button(action: addItem) {
                        Image(systemName: "plus.circle.fill")
                            .font(.title)
                            .foregroundColor(brandColor)
                    }
                    .buttonStyle(.borderless)
                }
            }
            .padding(.vertical, 8)

            ForEach(items, id: \.productid) { item in
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
}

// MARK: - View Isolada da Linha
struct OrderItemRow: View {
    let item: OrderItemInput
    let productName: String
    
    var itemTotal: Double {
        let totalCents = item.unitprice * item.quantity
        return Double(totalCents) / 100.0
    }
    
    var body: some View {
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
    }
}

// MARK: - Business Logic Helpers
extension NewOrderView {
    
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
        // Performance flaw: Consider mapping allProducts to a Dictionary on load
        allProducts.first(where: { $0.id == id })?.name ?? "Produto"
    }

    func loadData() async {
        do {
            let clients = try await orderService.fetchClients()
            let products = try await orderService.fetchProducts()
            await MainActor.run {
                self.allClients = clients
                self.allProducts = products
            }
        } catch {
            print("Erro ao carregar dados da API: \(error)")
        }
    }

    func addItem() {
        // String replacement for commas is fragile. Proper usage involves NumberFormatter parsing.
        let cleanedTotal = itemTotalPaid.replacingOccurrences(of: ",", with: ".")
        
        if let q = Int(quantity),
           let total = Double(cleanedTotal),
           !selectedProductId.isEmpty,
           q > 0 {
            
            let rawUnitPrice = total / Double(q)
            let unitPriceCents = Int(round(rawUnitPrice * 100))
            
            let newItem = OrderItemInput(productid: selectedProductId, quantity: q, unitprice: unitPriceCents)
            items.append(newItem)
            
            selectedProductId = ""
            quantity = "1"
            itemTotalPaid = ""
            isInputActive = false
        }
    }

    func handleSave() async {
        let dtoList = items.map { $0 }
        let finalInput = OrderInput(
            clientid: selectedClientId,
            deliverydate: Formatters.iso8601.string(from: deliveryDate),
            items: dtoList
        )
        
        do {
            try await orderService.createOrder(input: finalInput)
            await viewModel.loadOrders()
            await MainActor.run { dismiss() }
        } catch {
            print("❌ Erro: \(error)")
        }
    }
}
