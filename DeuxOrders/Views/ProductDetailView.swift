//
//  ProductDetailView.swift
//  DeuxOrders
//

import SwiftUI

struct ProductDetailView: View {
    let product: ProductResponse
    @ObservedObject var viewModel: ProductsViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var isEditing = false
    @State private var editName: String = ""
    @State private var editDescription: String = ""
    @State private var editPrice: String = ""
    @State private var editCategory: String = ""
    @State private var editSize: String = ""
    @State private var showDeleteAlert = false
    @State private var recipe: ProductRecipeResponse?
    @State private var recipeOptions: [ProductRecipeOptionResponse] = []
    @State private var orderOptions: ProductOrderOptionsResponse = .fallback
    @State private var materials: [MaterialDropdownItem] = []
    @State private var stats: ProductStats?
    @State private var isLoadingRecipe = false
    @State private var showBaseRecipeEditor = false
    @State private var recipeOptionToEdit: RecipeOptionEditorContext?


    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Product Image
                productImageSection

                // Product Info
                productInfoCard

                performanceCard

                // Price
                priceCard

                recipeCard

                // Status
                statusSection

                // Delete
                deleteSection
            }
            .padding()
        }
        .navigationTitle(product.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(isEditing ? "Salvar" : "Editar") {
                    if isEditing {
                        Task { await saveChanges() }
                    } else {
                        startEditing()
                    }
                }
                .foregroundColor(DSColor.brand)
            }
        }
        .alert("Excluir produto?", isPresented: $showDeleteAlert) {
            Button("Cancelar", role: .cancel) { }
            Button("Excluir", role: .destructive) {
                Task {
                    await viewModel.deleteProduct(id: product.id)
                    dismiss()
                }
            }
        } message: {
            Text("Esta ação não pode ser desfeita.")
        }
        .task { await loadRecipeData() }
        .sheet(isPresented: $showBaseRecipeEditor) {
            RecipeEditorSheet(
                title: "Receita base",
                materials: materials,
                initialItems: recipe?.items.map { ProductRecipeItemInput(materialId: $0.materialId, quantity: $0.quantity) } ?? [],
                onSave: { items in
                    Task {
                        if await viewModel.updateRecipe(productId: product.id, items: items) {
                            await loadRecipeData()
                            showBaseRecipeEditor = false
                        }
                    }
                }
            )
        }
        .sheet(item: $recipeOptionToEdit) { context in
            RecipeOptionEditorSheet(
                context: context,
                materials: materials,
                presets: orderOptions.names(for: context.type),
                onSave: { type, name, items in
                    Task {
                        if await viewModel.updateRecipeOption(productId: product.id, type: type, name: name, items: items) {
                            await loadRecipeData()
                            recipeOptionToEdit = nil
                        }
                    }
                }
            )
        }
    }

    // MARK: - Image

    private var productImageSection: some View {
        Group {
            if let imageUrl = product.image, let url = URL(string: imageUrl) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(height: 200)
                            .clipped()
                            .cornerRadius(16)
                    case .failure:
                        imagePlaceholder
                    default:
                        ProgressView()
                            .frame(height: 200)
                    }
                }
            } else {
                imagePlaceholder
            }
        }
    }

    private var imagePlaceholder: some View {
        VStack(spacing: 8) {
            Image(systemName: "photo")
                .font(.largeTitle)
                .foregroundColor(.secondary)
            Text("Sem imagem")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 160)
        .background(Color(uiColor: .secondarySystemBackground))
        .cornerRadius(16)
    }

    // MARK: - Info Card

    private var productInfoCard: some View {
        VStack(spacing: 0) {
            if isEditing {
                editableInfoFields
            } else {
                readOnlyInfo
            }
        }
        .background(Color(uiColor: .secondarySystemBackground))
        .cornerRadius(12)
    }

    private var readOnlyInfo: some View {
        VStack(spacing: 0) {
            infoRow(label: "Nome", value: product.name)

            if let desc = product.description, !desc.isEmpty {
                Divider().padding(.leading)
                infoRow(label: "Descrição", value: desc)
            }

            if let cat = product.category, !cat.isEmpty {
                Divider().padding(.leading)
                infoRow(label: "Categoria", value: cat)
            }

            if let size = product.size, !size.isEmpty {
                Divider().padding(.leading)
                infoRow(label: "Tamanho", value: size)
            }
        }
    }

    private var editableInfoFields: some View {
        VStack(spacing: 12) {
            editField(label: "Nome", text: $editName)
            editField(label: "Descrição", text: $editDescription)
            editField(label: "Categoria", text: $editCategory)
            editField(label: "Tamanho", text: $editSize)
        }
        .padding()
    }

    // MARK: - Performance

    private var performanceCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            DashboardSectionHeader(title: "DESEMPENHO")
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(stats?.soldThisMonth ?? 0)")
                        .font(.title2)
                        .fontWeight(.bold)
                    Text("Unid. vendidas")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
                .background(Color(uiColor: .tertiarySystemBackground))
                .cornerRadius(8)

                VStack(alignment: .leading, spacing: 4) {
                    Text(Formatters.brl(stats?.revenueThisMonth ?? 0))
                        .font(.title2)
                        .fontWeight(.bold)
                    Text("Receita")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
                .background(Color(uiColor: .tertiarySystemBackground))
                .cornerRadius(8)
            }
        }
        .padding()
        .background(Color(uiColor: .secondarySystemBackground))
        .cornerRadius(12)
    }

    // MARK: - Price

    private var priceCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            DashboardSectionHeader(title: "PREÇO")

            if isEditing {
                TextField("Preço", text: $editPrice)
                    .keyboardType(.decimalPad)
                    .textFieldStyle(.roundedBorder)
            } else {
                Text(formatPrice(product.price))
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(DSColor.brand)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(uiColor: .secondarySystemBackground))
        .cornerRadius(12)
    }

    // MARK: - Recipe

    private var recipeCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                DashboardSectionHeader(title: "RECEITAS")
                Spacer()
                if isLoadingRecipe {
                    ProgressView()
                }
            }

            VStack(alignment: .leading, spacing: 10) {
                recipeHeaderRow(
                    title: "Receita base",
                    subtitle: recipeItemsSummary(recipe?.items ?? []),
                    icon: "list.bullet.rectangle",
                    actionTitle: recipe?.hasRecipe == true ? "Editar" : "Adicionar"
                ) {
                    showBaseRecipeEditor = true
                }

                Divider()

                HStack {
                    Text("Opções")
                        .font(.subheadline.weight(.semibold))
                    Spacer()
                    Menu {
                        ForEach(ProductRecipeOptionType.allCases) { type in
                            Button(type.label) {
                                recipeOptionToEdit = RecipeOptionEditorContext(type: type, name: "", items: [])
                            }
                        }
                    } label: {
                        Label("Nova", systemImage: "plus.circle.fill")
                            .font(.caption.weight(.semibold))
                    }
                }

                if recipeOptions.isEmpty {
                    Text("Nenhuma opção cadastrada.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                } else {
                    ForEach(groupedRecipeOptions, id: \.type) { group in
                        VStack(alignment: .leading, spacing: 8) {
                            Text(group.type.label.uppercased())
                                .font(.caption2.weight(.bold))
                                .foregroundColor(DSColor.foregroundSoft)

                            ForEach(group.options) { option in
                                recipeHeaderRow(
                                    title: option.name,
                                    subtitle: recipeItemsSummary(option.items),
                                    icon: option.hasRecipe ? "checkmark.seal.fill" : "seal",
                                    actionTitle: "Editar"
                                ) {
                                    recipeOptionToEdit = RecipeOptionEditorContext(
                                        type: option.type,
                                        name: option.name,
                                        items: option.items.map { ProductRecipeItemInput(materialId: $0.materialId, quantity: $0.quantity) }
                                    )
                                }
                            }
                        }
                    }
                }
            }
        }
        .padding()
        .background(Color(uiColor: .secondarySystemBackground))
        .cornerRadius(12)
    }

    private var groupedRecipeOptions: [(type: ProductRecipeOptionType, options: [ProductRecipeOptionResponse])] {
        ProductRecipeOptionType.allCases.compactMap { type in
            let options = recipeOptions
                .filter { $0.type == type }
                .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
            return options.isEmpty ? nil : (type, options)
        }
    }

    private func recipeHeaderRow(
        title: String,
        subtitle: String,
        icon: String,
        actionTitle: String,
        action: @escaping () -> Void
    ) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .foregroundColor(DSColor.brand)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
            Spacer()
            Button(actionTitle, action: action)
                .font(.caption.weight(.semibold))
                .buttonStyle(.borderless)
                .foregroundColor(DSColor.brand)
        }
    }

    private func recipeItemsSummary(_ items: [ProductRecipeItem]) -> String {
        guard !items.isEmpty else { return "Sem ingredientes" }
        return items.prefix(3).map { item in
            let unit = item.measureUnit?.label ?? ""
            let name = item.materialName ?? item.materialId
            return "\(formatQuantity(item.quantity))\(unit) \(name)"
        }.joined(separator: ", ") + (items.count > 3 ? "..." : "")
    }

    // MARK: - Status

    private var statusSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Status")
                    .font(.subheadline)
                    .fontWeight(.medium)
                Text(product.status ? "Ativo" : "Inativo")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Toggle("", isOn: Binding(
                get: { product.status },
                set: { newValue in
                    Task {
                        if newValue {
                            await viewModel.activateProduct(id: product.id)
                        } else {
                            await viewModel.deactivateProduct(id: product.id)
                        }
                    }
                }
            ))
            .tint(DSColor.brand)
        }
        .padding()
        .background(Color(uiColor: .secondarySystemBackground))
        .cornerRadius(12)
    }

    // MARK: - Delete

    private var deleteSection: some View {
        Button(role: .destructive) {
            showDeleteAlert = true
        } label: {
            HStack {
                Image(systemName: "trash")
                Text("Excluir produto")
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
        }
        .background(Color.red.opacity(0.1))
        .cornerRadius(12)
    }

    // MARK: - Helpers

    private func infoRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .font(.subheadline)
                .multilineTextAlignment(.trailing)
        }
        .padding(.vertical, 10)
        .padding(.horizontal)
    }

    private func editField(label: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
            TextField(label, text: text)
                .textFieldStyle(.roundedBorder)
        }
    }

    private func startEditing() {
        editName = product.name
        editDescription = product.description ?? ""
        editPrice = String(format: "%.2f", Double(product.price) / 100.0).replacingOccurrences(of: ".", with: ",")
        editCategory = product.category ?? ""
        editSize = product.size ?? ""
        isEditing = true
    }

    private func saveChanges() async {
        let priceValue = Double(editPrice.replacingOccurrences(of: ",", with: "."))
            ?? (Double(product.price) / 100.0)
        let priceCents = Double(Int(round(priceValue * 100)))
        let _ = await viewModel.updateProduct(
            id: product.id,
            name: editName,
            description: editDescription,
            price: priceCents,
            category: editCategory.isEmpty ? nil : editCategory,
            size: editSize.isEmpty ? nil : editSize
        )
        isEditing = false
    }

    private func formatPrice(_ price: Int) -> String {
        Formatters.brl(price)
    }

    private func loadRecipeData() async {
        isLoadingRecipe = true
        defer { isLoadingRecipe = false }

        async let recipeTask = try? viewModel.fetchRecipe(productId: product.id)
        async let optionsTask = try? viewModel.fetchRecipeOptions(productId: product.id)
        async let orderOptionsTask = viewModel.fetchOrderOptions(productId: product.id)
        async let materialsTask = try? InventoryService().fetchDropdown()
        async let statsTask = try? viewModel.fetchStats(productId: product.id, month: currentMonth)

        recipe = await recipeTask
        recipeOptions = await optionsTask ?? []
        orderOptions = await orderOptionsTask
        materials = await materialsTask ?? []
        stats = await statsTask
    }

    private func formatQuantity(_ quantity: Double) -> String {
        quantity.truncatingRemainder(dividingBy: 1) == 0 ? String(Int(quantity)) : String(format: "%.1f", quantity)
    }

    private var currentMonth: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM"
        return formatter.string(from: Date())
    }
}

struct RecipeOptionEditorContext: Identifiable {
    let id = UUID()
    var type: ProductRecipeOptionType
    var name: String
    var items: [ProductRecipeItemInput]
}

struct RecipeEditorSheet: View {
    @Environment(\.dismiss) private var dismiss
    let title: String
    let materials: [MaterialDropdownItem]
    let initialItems: [ProductRecipeItemInput]
    let onSave: ([ProductRecipeItemInput]) -> Void

    @State private var items: [ProductRecipeItemInput]
    @State private var selectedMaterialId = ""
    @State private var quantityText = ""

    init(
        title: String,
        materials: [MaterialDropdownItem],
        initialItems: [ProductRecipeItemInput],
        onSave: @escaping ([ProductRecipeItemInput]) -> Void
    ) {
        self.title = title
        self.materials = materials
        self.initialItems = initialItems
        self.onSave = onSave
        _items = State(initialValue: initialItems)
    }

    var body: some View {
        NavigationStack {
            Form {
                ingredientsSection
                addIngredientSection
                clearSection
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Salvar") { onSave(items) }
                }
            }
        }
    }

    private var ingredientsSection: some View {
        Section("Ingredientes") {
            if items.isEmpty {
                Text("Nenhum ingrediente.")
                    .foregroundColor(.secondary)
            } else {
                ForEach(items) { item in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(materialName(item.materialId))
                            Text(materialUnit(item.materialId))
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        TextField("Qtd", value: quantityBinding(for: item.materialId), format: .number)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 90)
                    }
                }
                .onDelete { offsets in items.remove(atOffsets: offsets) }
            }
        }
    }

    private var addIngredientSection: some View {
        Section("Adicionar") {
            Picker("Material", selection: $selectedMaterialId) {
                Text("Selecione").tag("")
                ForEach(materials) { material in
                    Text("\(material.name) (\(material.measureUnit.label))").tag(material.id)
                }
            }

            TextField("Quantidade", text: $quantityText)
                .keyboardType(.decimalPad)

            Button {
                addIngredient()
            } label: {
                Label("Adicionar ingrediente", systemImage: "plus.circle.fill")
            }
            .disabled(!canAddIngredient)
        }
    }

    private var clearSection: some View {
        Section {
            Button(role: .destructive) {
                items = []
            } label: {
                Label("Limpar receita", systemImage: "trash")
            }
        }
    }

    private var canAddIngredient: Bool {
        !selectedMaterialId.isEmpty && parsedQuantity != nil
    }

    private var parsedQuantity: Double? {
        let value = Double(quantityText.replacingOccurrences(of: ",", with: "."))
        guard let value, value > 0 else { return nil }
        return value
    }

    private func addIngredient() {
        guard let quantity = parsedQuantity else { return }
        if let index = items.firstIndex(where: { $0.materialId == selectedMaterialId }) {
            items[index].quantity = quantity
        } else {
            items.append(ProductRecipeItemInput(materialId: selectedMaterialId, quantity: quantity))
        }
        selectedMaterialId = ""
        quantityText = ""
    }

    private func quantityBinding(for materialId: String) -> Binding<Double> {
        Binding(
            get: { items.first(where: { $0.materialId == materialId })?.quantity ?? 0 },
            set: { newValue in
                if let index = items.firstIndex(where: { $0.materialId == materialId }) {
                    items[index].quantity = max(0, newValue)
                }
            }
        )
    }

    private func materialName(_ id: String) -> String {
        materials.first(where: { $0.id == id })?.name ?? id
    }

    private func materialUnit(_ id: String) -> String {
        materials.first(where: { $0.id == id })?.measureUnit.label ?? ""
    }
}

struct RecipeOptionEditorSheet: View {
    @Environment(\.dismiss) private var dismiss
    let context: RecipeOptionEditorContext
    let materials: [MaterialDropdownItem]
    let presets: [String]
    let onSave: (ProductRecipeOptionType, String, [ProductRecipeItemInput]) -> Void

    @State private var type: ProductRecipeOptionType
    @State private var name: String
    @State private var selectedPreset = ""
    @State private var items: [ProductRecipeItemInput]
    @State private var selectedMaterialId = ""
    @State private var quantityText = ""

    init(
        context: RecipeOptionEditorContext,
        materials: [MaterialDropdownItem],
        presets: [String],
        onSave: @escaping (ProductRecipeOptionType, String, [ProductRecipeItemInput]) -> Void
    ) {
        self.context = context
        self.materials = materials
        self.presets = Array(Set(presets)).sorted()
        self.onSave = onSave
        _type = State(initialValue: context.type)
        _name = State(initialValue: context.name)
        _items = State(initialValue: context.items)
        _selectedPreset = State(initialValue: context.name)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Opção") {
                    Picker("Tipo", selection: $type) {
                        ForEach(ProductRecipeOptionType.allCases) { type in
                            Text(type.label).tag(type)
                        }
                    }

                    if !presets.isEmpty {
                        Picker("Nome", selection: $selectedPreset) {
                            Text("Personalizado").tag("")
                            ForEach(presets, id: \.self) { preset in
                                Text(preset).tag(preset)
                            }
                        }
                        .onChange(of: selectedPreset) { _, value in
                            if !value.isEmpty { name = value }
                        }
                    }

                    TextField("Nome", text: $name)
                }

                ingredientsSection
                addIngredientSection
                clearSection
            }
            .navigationTitle(context.name.isEmpty ? "Nova opção" : context.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Salvar") { onSave(type, name, items) }
                        .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }

    private var ingredientsSection: some View {
        Section("Ingredientes") {
            if items.isEmpty {
                Text("Nenhum ingrediente.")
                    .foregroundColor(.secondary)
            } else {
                ForEach(items) { item in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(materialName(item.materialId))
                            Text(materialUnit(item.materialId))
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        TextField("Qtd", value: quantityBinding(for: item.materialId), format: .number)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 90)
                    }
                }
                .onDelete { offsets in items.remove(atOffsets: offsets) }
            }
        }
    }

    private var addIngredientSection: some View {
        Section("Adicionar") {
            Picker("Material", selection: $selectedMaterialId) {
                Text("Selecione").tag("")
                ForEach(materials) { material in
                    Text("\(material.name) (\(material.measureUnit.label))").tag(material.id)
                }
            }

            TextField("Quantidade", text: $quantityText)
                .keyboardType(.decimalPad)

            Button {
                addIngredient()
            } label: {
                Label("Adicionar ingrediente", systemImage: "plus.circle.fill")
            }
            .disabled(!canAddIngredient)
        }
    }

    private var clearSection: some View {
        Section {
            Button(role: .destructive) {
                items = []
            } label: {
                Label("Limpar opção", systemImage: "trash")
            }
        }
    }

    private var canAddIngredient: Bool {
        !selectedMaterialId.isEmpty && parsedQuantity != nil
    }

    private var parsedQuantity: Double? {
        let value = Double(quantityText.replacingOccurrences(of: ",", with: "."))
        guard let value, value > 0 else { return nil }
        return value
    }

    private func addIngredient() {
        guard let quantity = parsedQuantity else { return }
        if let index = items.firstIndex(where: { $0.materialId == selectedMaterialId }) {
            items[index].quantity = quantity
        } else {
            items.append(ProductRecipeItemInput(materialId: selectedMaterialId, quantity: quantity))
        }
        selectedMaterialId = ""
        quantityText = ""
    }

    private func quantityBinding(for materialId: String) -> Binding<Double> {
        Binding(
            get: { items.first(where: { $0.materialId == materialId })?.quantity ?? 0 },
            set: { newValue in
                if let index = items.firstIndex(where: { $0.materialId == materialId }) {
                    items[index].quantity = max(0, newValue)
                }
            }
        )
    }

    private func materialName(_ id: String) -> String {
        materials.first(where: { $0.id == id })?.name ?? id
    }

    private func materialUnit(_ id: String) -> String {
        materials.first(where: { $0.id == id })?.measureUnit.label ?? ""
    }
}
