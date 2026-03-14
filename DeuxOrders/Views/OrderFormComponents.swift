import SwiftUI

private let brandColor = Color(red: 88/255, green: 22/255, blue: 41/255)
private let maxObservationLength = 500

struct OrderBasicInfoSection: View {
    let allClients: [Client]
    @Binding var selectedClientId: String
    @Binding var deliveryDate: Date

    var body: some View {
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
}

struct AddItemFormSection: View {
    let allProducts: [ProductResponse]
    let sectionTitle: String
    @Binding var selectedProductId: String
    @Binding var quantity: String
    @Binding var itemTotalPaid: String
    @Binding var itemObservation: String
    @FocusState.Binding var isInputActive: Bool
    let items: [OrderItemInput]
    let onAdd: () -> Void
    let onDelete: (IndexSet) -> Void

    var body: some View {
        Section(sectionTitle) {
            VStack(spacing: 12) {
                Picker("Produto", selection: $selectedProductId) {
                    Text("Selecione o produto").tag(String(""))
                    ForEach(allProducts) { prod in
                        if prod.status { Text(prod.name).tag(prod.id) }
                    }
                }
                .pickerStyle(.menu)
                .onChange(of: selectedProductId) { _, newValue in updateTotalPaid(for: newValue) }

                HStack {
                    TextField("Qtd", text: $quantity)
                        .keyboardType(.numberPad)
                        .textFieldStyle(.roundedBorder)
                        .focused($isInputActive)
                        .onChange(of: quantity) { _, _ in updateTotalPaid(for: selectedProductId) }

                    TextField("Total Pago", text: $itemTotalPaid)
                        .keyboardType(.decimalPad)
                        .textFieldStyle(.roundedBorder)
                        .focused($isInputActive)
                }

                HStack {
                    TextField("Observação (opcional)", text: $itemObservation)
                        .textFieldStyle(.roundedBorder)
                        .focused($isInputActive)
                        .onChange(of: itemObservation) { _, newValue in
                            if newValue.count > maxObservationLength {
                                itemObservation = String(newValue.prefix(maxObservationLength))
                            }
                        }

                    Button(action: onAdd) {
                        Image(systemName: "plus.circle.fill")
                            .font(.title)
                            .foregroundColor(brandColor)
                    }
                    .buttonStyle(.borderless)
                }
            }
            .padding(.vertical, 8)

            ForEach(items) { item in
                OrderItemRow(item: item, productName: productName(for: item.productid))
            }
            .onDelete(perform: onDelete)
        }
    }

    private func updateTotalPaid(for productId: String) {
        guard let prod = allProducts.first(where: { $0.id == productId }),
              let q = Int(quantity) else { return }
        let total = (Double(prod.price) / 100.0) * Double(q)
        itemTotalPaid = String(format: "%.2f", total)
    }

    private func productName(for id: String) -> String {
        allProducts.first(where: { $0.id == id })?.name ?? "Produto Desconhecido"
    }
}

struct OrderTotalSection: View {
    let totalOrderValue: Double

    var body: some View {
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
