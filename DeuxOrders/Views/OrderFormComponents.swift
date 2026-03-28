import SwiftUI
import PhotosUI

private let brandColor = Color(red: 88/255, green: 22/255, blue: 41/255)
private let maxObservationLength = 500

struct OrderBasicInfoSection: View {
    let allClients: [Client]
    @Binding var selectedClientId: String
    @Binding var deliveryDate: Date
    @Binding var deliveryAddress: String

    private var isPickup: Bool {
        deliveryAddress == "Retirada"
    }

    private var modeBinding: Binding<Bool> {
        Binding(
            get: { isPickup },
            set: { newIsPickup in
                deliveryAddress = newIsPickup ? "Retirada" : ""
            }
        )
    }

    var body: some View {
        Section("Informações Básicas") {
            Picker("Cliente", selection: $selectedClientId) {
                Text("Selecione um cliente").tag(String(""))
                ForEach(allClients) { client in
                    Text(client.name).tag(client.id)
                }
            }
            DatePicker("Entrega", selection: $deliveryDate, displayedComponents: [.date, .hourAndMinute])
            Picker("Tipo", selection: modeBinding) {
                Text("Retirada").tag(true)
                Text("Entrega").tag(false)
            }
            .pickerStyle(.segmented)
            if !isPickup {
                TextField("Endereço de entrega", text: $deliveryAddress)
            }
        }
    }
}

struct AddItemFormSection: View {
    let allProducts: [ProductResponse]
    let sectionTitle: String
    @Binding var selectedProductId: String
    @Binding var quantity: String
    @Binding var itemUnitPrice: String
    @Binding var itemMassa: String
    @Binding var itemSabor: String
    @Binding var itemObservation: String
    @FocusState.Binding var isInputActive: Bool
    let items: [OrderItemInput]
    let onAdd: () -> Void
    let onDelete: (IndexSet) -> Void

    @State private var selectedProductName: String = ""
    @State private var selectedSize: String = ""

    private var uniqueProductNames: [String] {
        var seen = Set<String>()
        return allProducts
            .filter { $0.status }
            .compactMap { seen.insert($0.name).inserted ? $0.name : nil }
            .sorted()
    }

    private var sizesForSelectedName: [String] {
        var seen = Set<String>()
        return allProducts
            .filter { $0.status && $0.name == selectedProductName }
            .compactMap { $0.size.flatMap { $0.isEmpty ? nil : $0 } }
            .filter { seen.insert($0).inserted }
    }

    private var requiresMassaSabor: Bool {
        guard !selectedProductId.isEmpty,
              let product = allProducts.first(where: { $0.id == selectedProductId }) else { return false }
        return product.category?.lowercased() == "bolo" || product.name.lowercased() == "brigadeiro"
    }

    private var canAddItem: Bool {
        !selectedProductId.isEmpty &&
        (Int(quantity) ?? 0) > 0 &&
        (Double(itemUnitPrice.replacingOccurrences(of: ",", with: ".")) ?? 0) > 0 &&
        (!requiresMassaSabor || (!itemMassa.isEmpty && !itemSabor.isEmpty))
    }

    var body: some View {
        Section(sectionTitle) {
            VStack(spacing: 12) {
                Picker("Produto", selection: $selectedProductName) {
                    Text("Selecione o produto").tag(String(""))
                    ForEach(uniqueProductNames, id: \.self) { Text($0).tag($0) }
                }
                .pickerStyle(.menu)
                .onChange(of: selectedProductName) { _, name in
                    selectedSize = ""
                    resolveProductId(name: name, size: "")
                }

                if !sizesForSelectedName.isEmpty {
                    Picker("Tamanho", selection: $selectedSize) {
                        Text("Selecione o tamanho").tag(String(""))
                        ForEach(sizesForSelectedName, id: \.self) { Text($0).tag($0) }
                    }
                    .pickerStyle(.menu)
                    .onChange(of: selectedSize) { _, size in
                        resolveProductId(name: selectedProductName, size: size)
                    }
                }

                HStack {
                    TextField("Qtd", text: $quantity)
                        .keyboardType(.numberPad)
                        .textFieldStyle(.roundedBorder)
                        .focused($isInputActive)
                        .frame(maxWidth: 70)
                        .onChange(of: quantity) { _, _ in autoFillUnitPrice(for: selectedProductId) }

                    TextField("Preço unit. (R$)", text: $itemUnitPrice)
                        .keyboardType(.decimalPad)
                        .textFieldStyle(.roundedBorder)
                        .focused($isInputActive)
                }

                if requiresMassaSabor {
                    TextField("Massa", text: $itemMassa)
                        .textFieldStyle(.roundedBorder)
                        .focused($isInputActive)
                    TextField("Sabor", text: $itemSabor)
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
                    .disabled(!canAddItem)
                }
            }
            .padding(.vertical, 8)
            .onChange(of: selectedProductId) { _, newId in
                if newId.isEmpty {
                    selectedProductName = ""
                    selectedSize = ""
                    itemUnitPrice = ""
                    itemMassa = ""
                    itemSabor = ""
                } else {
                    autoFillUnitPrice(for: newId)
                }
            }

            ForEach(items) { item in
                OrderItemRow(item: item, productName: productName(for: item.productid), productSize: productSize(for: item.productid))
            }
            .onDelete(perform: onDelete)
        }
    }

    private func resolveProductId(name: String, size: String) {
        guard !name.isEmpty else {
            selectedProductId = ""
            return
        }
        let candidates = allProducts.filter { $0.status && $0.name == name }
        if sizesForSelectedName.isEmpty {
            selectedProductId = candidates.first?.id ?? ""
        } else if !size.isEmpty {
            selectedProductId = candidates.first(where: { $0.size == size })?.id ?? ""
        } else {
            selectedProductId = ""
        }
        autoFillUnitPrice(for: selectedProductId)
    }

    private func autoFillUnitPrice(for productId: String) {
        guard !productId.isEmpty,
              let prod = allProducts.first(where: { $0.id == productId }) else { return }
        itemUnitPrice = String(format: "%.2f", prod.price / 100.0)
    }

    private func productName(for id: String) -> String {
        allProducts.first(where: { $0.id == id })?.name ?? "Produto Desconhecido"
    }

    private func productSize(for id: String) -> String? {
        guard let size = allProducts.first(where: { $0.id == id })?.size, !size.isEmpty else { return nil }
        return size
    }
}

private enum FullscreenImageSource: Identifiable {
    case url(String)
    case local(Int, UIImage)

    var id: String {
        switch self {
        case .url(let s): return s
        case .local(let i, _): return "local-\(i)"
        }
    }
}

private struct FullscreenImageViewer: View {
    let source: FullscreenImageSource
    @Environment(\.dismiss) var dismiss

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Color.black.ignoresSafeArea()
            Group {
                switch source {
                case .url(let urlString):
                    AsyncImage(url: URL(string: urlString)) { image in
                        image.resizable().scaledToFit()
                    } placeholder: {
                        ProgressView().tint(.white)
                    }
                case .local(_, let uiImage):
                    Image(uiImage: uiImage).resizable().scaledToFit()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            Button { dismiss() } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.title)
                    .foregroundStyle(.white, Color.gray.opacity(0.8))
                    .padding()
            }
        }
    }
}

struct ReferenceImagesSection: View {
    @Binding var selectedImages: [UIImage]
    var existingUrls: [String] = []
    var onDeleteExisting: ((String) -> Void)? = nil
    private let maxImages = 3

    @State private var pickerItems: [PhotosPickerItem] = []
    @State private var fullscreenSource: FullscreenImageSource?

    private var remainingSlots: Int {
        maxImages - existingUrls.count - selectedImages.count
    }

    var body: some View {
        Section("Imagens de Referência") {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(existingUrls, id: \.self) { url in
                        ZStack(alignment: .topTrailing) {
                            AsyncImage(url: URL(string: url)) { image in
                                image.resizable().scaledToFill()
                            } placeholder: {
                                Color.secondary.opacity(0.2).overlay { ProgressView() }
                            }
                            .frame(width: 80, height: 80)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .onTapGesture { fullscreenSource = .url(url) }

                            if onDeleteExisting != nil {
                                Button {
                                    onDeleteExisting?(url)
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundStyle(.white, brandColor)
                                }
                                .padding(4)
                            }
                        }
                    }

                    ForEach(Array(selectedImages.enumerated()), id: \.offset) { index, image in
                        ZStack(alignment: .topTrailing) {
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 80, height: 80)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                                .onTapGesture { fullscreenSource = .local(index, image) }
                            Button {
                                selectedImages.remove(at: index)
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundStyle(.white, brandColor)
                            }
                            .padding(4)
                        }
                    }

                    if remainingSlots > 0 {
                        PhotosPicker(selection: $pickerItems, maxSelectionCount: remainingSlots, matching: .images) {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.secondary.opacity(0.15))
                                .frame(width: 80, height: 80)
                                .overlay {
                                    Image(systemName: "plus")
                                        .font(.title2)
                                        .foregroundColor(.secondary)
                                }
                        }
                    }
                }
                .padding(.vertical, 4)
            }
        }
        .onChange(of: pickerItems) { _, items in
            Task { await loadImages(from: items) }
        }
        .fullScreenCover(item: $fullscreenSource) { source in
            FullscreenImageViewer(source: source)
        }
    }

    private func loadImages(from items: [PhotosPickerItem]) async {
        for item in items {
            if let data = try? await item.loadTransferable(type: Data.self),
               let image = UIImage(data: data) {
                await MainActor.run { selectedImages.append(image) }
            }
        }
        await MainActor.run { pickerItems = [] }
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
