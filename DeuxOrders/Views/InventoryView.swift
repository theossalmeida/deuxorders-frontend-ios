import SwiftUI

struct InventoryView: View {
    @StateObject private var viewModel = InventoryViewModel()
    @State private var searchText = ""
    @State private var statusFilter: Bool? = true
    @State private var showNewMaterial = false

    private var filteredMaterials: [Material] {
        viewModel.materials.filter { mat in
            let searchMatch = searchText.isEmpty || mat.name.localizedCaseInsensitiveContains(searchText)
            let statusMatch = statusFilter == nil || mat.status == statusFilter
            return searchMatch && statusMatch
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                topBar
                contentView
            }
            .background(DSColor.background)
            .navigationTitle("Estoque")
            .task { await viewModel.loadMaterials(status: statusFilter) }
            .onChange(of: statusFilter) { _, newValue in
                Task { await viewModel.loadMaterials(search: searchText, status: newValue) }
            }
            .onSubmit(of: .text) {
                Task { await viewModel.loadMaterials(search: searchText, status: statusFilter) }
            }
            .sheet(isPresented: $showNewMaterial) {
                NewMaterialSheet(viewModel: viewModel)
            }
            .alert("Atenção", isPresented: Binding<Bool>(
                get: { viewModel.errorMessage != nil },
                set: { if !$0 { viewModel.errorMessage = nil } }
            )) {
                Button("OK", role: .cancel) { }
            } message: {
                if let msg = viewModel.errorMessage { Text(msg) }
            }
        }
    }

    @ViewBuilder
    private var contentView: some View {
        if viewModel.isLoading && viewModel.materials.isEmpty {
            Spacer()
            ProgressView("Carregando materiais...")
            Spacer()
        } else if filteredMaterials.isEmpty {
            ContentUnavailableView("Nenhum material encontrado", systemImage: "shippingbox")
        } else {
            List {
                ForEach(filteredMaterials) { mat in
                    NavigationLink(destination: MaterialDetailView(material: mat, viewModel: viewModel)) {
                        MaterialRow(material: mat)
                    }
                    .listRowBackground(Color.white)
                    .swipeActions(edge: .leading, allowsFullSwipe: true) {
                        if mat.status {
                            Button { Task { await viewModel.deactivateMaterial(id: mat.id) } } label: {
                                Label("Desativar", systemImage: "xmark.circle")
                            }.tint(.orange)
                        } else {
                            Button { Task { await viewModel.activateMaterial(id: mat.id) } } label: {
                                Label("Ativar", systemImage: "checkmark.circle")
                            }.tint(.green)
                        }
                    }
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .refreshable { await viewModel.loadMaterials(search: searchText, status: statusFilter) }
        }
    }

    private var topBar: some View {
        HStack(spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .font(.subheadline)
                    .foregroundColor(DSColor.foregroundSoft)
                TextField("Buscar material...", text: $searchText)
                    .textFieldStyle(.plain)
                    .font(.subheadline)
                    .autocorrectionDisabled()
                    .submitLabel(.search)
            }
            .padding(10)
            .background(DSColor.background2)
            .cornerRadius(10)

            Menu {
                Picker("Status", selection: $statusFilter) {
                    Text("Todos").tag(Bool?.none)
                    Text("Ativos").tag(Bool?.some(true))
                    Text("Inativos").tag(Bool?.some(false))
                }
            } label: {
                Image(systemName: "line.3.horizontal.decrease.circle")
                    .font(.title3)
                    .foregroundColor(DSColor.foregroundSoft)
            }

            Button { showNewMaterial = true } label: {
                Image(systemName: "plus.circle.fill")
                    .font(.title3)
                    .foregroundColor(DSColor.brand)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color.white)
    }
}

// MARK: - Material Row

struct MaterialRow: View {
    let material: Material

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(material.name)
                        .font(DSFont.cardTitle)
                        .foregroundColor(DSColor.foreground)
                    if !material.status {
                        Text("Inativo")
                            .font(.caption2)
                            .fontWeight(.bold)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.gray.opacity(0.2))
                            .foregroundColor(.gray)
                            .cornerRadius(4)
                    }
                }
                HStack(spacing: 4) {
                    Text(formatQuantity(material.quantity))
                        .font(DSFont.monoCaption)
                    Text(material.measureUnit.label)
                        .font(.caption2)
                        .foregroundColor(DSColor.foregroundSoft)
                }
                if material.quantity < 0 {
                    Text("Estoque negativo")
                        .font(.caption2)
                        .foregroundColor(DSColor.destructive)
                }
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text(Formatters.brl(material.unitCost))
                    .font(DSFont.monoCaption)
                    .foregroundColor(DSColor.foreground)
                Text("por \(material.measureUnit.label)")
                    .font(.caption2)
                    .foregroundColor(DSColor.foregroundSoft)
            }
        }
        .padding(.vertical, 4)
    }

    private func formatQuantity(_ q: Double) -> String {
        q.truncatingRemainder(dividingBy: 1) == 0 ? String(Int(q)) : String(format: "%.1f", q)
    }
}

// MARK: - New Material Sheet

struct NewMaterialSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: InventoryViewModel

    @State private var name = ""
    @State private var quantity = ""
    @State private var totalCost = ""
    @State private var measureUnit: MeasureUnit = .g
    @State private var isSubmitting = false

    var isValid: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty &&
        (Double(quantity.replacingOccurrences(of: ",", with: ".")) ?? 0) > 0 &&
        (Double(totalCost.replacingOccurrences(of: ",", with: ".")) ?? 0) >= 0
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Dados do Material") {
                    TextField("Nome *", text: $name)
                    Picker("Unidade", selection: $measureUnit) {
                        ForEach(MeasureUnit.allCases, id: \.intValue) { unit in
                            Text(unit.label).tag(unit)
                        }
                    }
                    TextField("Quantidade inicial *", text: $quantity)
                        .keyboardType(.decimalPad)
                    TextField("Custo total (R$)", text: $totalCost)
                        .keyboardType(.decimalPad)
                }
            }
            .navigationTitle("Novo Material")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Salvar") { submit() }
                        .disabled(!isValid || isSubmitting)
                }
            }
        }
    }

    private func submit() {
        isSubmitting = true
        let qty = Double(quantity.replacingOccurrences(of: ",", with: ".")) ?? 0
        let cost = Double(totalCost.replacingOccurrences(of: ",", with: ".")) ?? 0
        Task {
            let success = await viewModel.createMaterial(name: name, quantity: qty, totalCostReais: cost, measureUnit: measureUnit)
            isSubmitting = false
            if success { dismiss() }
        }
    }
}

// MARK: - Material Detail

struct MaterialDetailView: View {
    let material: Material
    @ObservedObject var viewModel: InventoryViewModel
    @State private var showRestock = false
    @State private var showEdit = false

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Main info card
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text(material.name)
                            .font(.title3)
                            .fontWeight(.bold)
                        Spacer()
                        Text(material.status ? "Ativo" : "Inativo")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(material.status ? DSColor.ok.opacity(0.12) : Color.gray.opacity(0.2))
                            .foregroundColor(material.status ? DSColor.ok : .gray)
                            .cornerRadius(8)
                    }

                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                        infoTile(title: "Quantidade", value: formatQuantity(material.quantity), unit: material.measureUnit.label)
                        infoTile(title: "Custo unitário", value: Formatters.brl(material.unitCost), unit: "por \(material.measureUnit.label)")
                    }
                }
                .padding()
                .background(Color.white)
                .cornerRadius(12)

                // Actions
                VStack(spacing: 10) {
                    Button {
                        showRestock = true
                    } label: {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                            Text("Reabastecer")
                        }
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .foregroundColor(.white)
                        .background(DSColor.brand)
                        .cornerRadius(12)
                    }

                    Button {
                        showEdit = true
                    } label: {
                        HStack {
                            Image(systemName: "pencil")
                            Text("Editar")
                        }
                        .font(.subheadline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .foregroundColor(DSColor.brand)
                        .background(DSColor.brandSoft)
                        .cornerRadius(12)
                    }

                    Button {
                        Task {
                            if material.status {
                                await viewModel.deactivateMaterial(id: material.id)
                            } else {
                                await viewModel.activateMaterial(id: material.id)
                            }
                        }
                    } label: {
                        Text(material.status ? "Desativar" : "Ativar")
                            .font(.subheadline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .foregroundColor(material.status ? DSColor.destructive : DSColor.ok)
                    }
                }
            }
            .padding()
        }
        .background(DSColor.background)
        .navigationTitle(material.name)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showRestock) {
            RestockSheet(material: material, viewModel: viewModel)
        }
        .sheet(isPresented: $showEdit) {
            EditMaterialSheet(material: material, viewModel: viewModel)
        }
    }

    private func infoTile(title: String, value: String, unit: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(DSFont.sectionLabel)
                .foregroundColor(DSColor.foregroundSoft)
                .textCase(.uppercase)
            Text(value)
                .font(DSFont.primaryAmount)
                .foregroundColor(DSColor.foreground)
            Text(unit)
                .font(.caption2)
                .foregroundColor(DSColor.foregroundSoft)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(DSColor.background2)
        .cornerRadius(10)
    }

    private func formatQuantity(_ q: Double) -> String {
        q.truncatingRemainder(dividingBy: 1) == 0 ? String(Int(q)) : String(format: "%.1f", q)
    }
}

// MARK: - Restock Sheet

struct RestockSheet: View {
    let material: Material
    @ObservedObject var viewModel: InventoryViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var quantity = ""
    @State private var totalCost = ""
    @State private var isSubmitting = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Reabastecer \(material.name)") {
                    TextField("Quantidade", text: $quantity)
                        .keyboardType(.decimalPad)
                    TextField("Custo total (R$)", text: $totalCost)
                        .keyboardType(.decimalPad)
                }
            }
            .navigationTitle("Reabastecer")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancelar") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Confirmar") {
                        isSubmitting = true
                        let qty = Double(quantity.replacingOccurrences(of: ",", with: ".")) ?? 0
                        let cost = Double(totalCost.replacingOccurrences(of: ",", with: ".")) ?? 0
                        Task {
                            let success = await viewModel.restockMaterial(id: material.id, quantity: qty, totalCostReais: cost)
                            isSubmitting = false
                            if success { dismiss() }
                        }
                    }
                    .disabled(!isValid || isSubmitting)
                }
            }
        }
    }

    private var isValid: Bool {
        (Double(quantity.replacingOccurrences(of: ",", with: ".")) ?? 0) > 0 &&
        (Double(totalCost.replacingOccurrences(of: ",", with: ".")) ?? 0) >= 0
    }
}

// MARK: - Edit Material Sheet

struct EditMaterialSheet: View {
    let material: Material
    @ObservedObject var viewModel: InventoryViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var name: String
    @State private var measureUnit: MeasureUnit
    @State private var isSubmitting = false

    init(material: Material, viewModel: InventoryViewModel) {
        self.material = material
        self.viewModel = viewModel
        _name = State(initialValue: material.name)
        _measureUnit = State(initialValue: material.measureUnit)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Editar Material") {
                    TextField("Nome", text: $name)
                    Picker("Unidade", selection: $measureUnit) {
                        ForEach(MeasureUnit.allCases, id: \.intValue) { unit in
                            Text(unit.label).tag(unit)
                        }
                    }
                }
            }
            .navigationTitle("Editar")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancelar") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Salvar") {
                        isSubmitting = true
                        Task {
                            let success = await viewModel.updateMaterial(id: material.id, name: name, measureUnit: measureUnit)
                            isSubmitting = false
                            if success { dismiss() }
                        }
                    }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty || isSubmitting)
                }
            }
        }
    }
}
