import SwiftUI
import PhotosUI

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
