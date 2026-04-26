import SwiftUI

struct OrdersView: View {
    @ObservedObject var viewModel: OrdersViewModel

    @State private var searchText = ""
    @State private var selectedStatus: OrderStatus? = nil
    @State private var startDate = Date()
    @State private var endDate = Calendar.current.date(byAdding: .day, value: 6, to: Date()) ?? Date()
    @State private var showDatePicker = false
    @State private var showingNewOrderSheet = false
    @StateObject private var newOrderState = NewOrderState()

    private var filteredOrders: [Order] {
        let calendar = Calendar.current
        let startOfStartDate = calendar.startOfDay(for: startDate)
        let endOfEndDate = calendar.date(bySettingHour: 23, minute: 59, second: 59, of: endDate) ?? endDate

        return viewModel.orders.filter { order in
            let searchMatch = searchText.isEmpty ||
                order.clientName.localizedCaseInsensitiveContains(searchText) ||
                order.id.localizedCaseInsensitiveContains(searchText)
            let statusMatch = selectedStatus == nil || order.status == selectedStatus
            let dateMatch = order.deliveryDate >= startOfStartDate && order.deliveryDate <= endOfEndDate
            return searchMatch && statusMatch && dateMatch
        }
    }

    private var groupedOrders: [(key: Date, orders: [Order])] {
        let cal = Calendar.current
        let grouped = Dictionary(grouping: filteredOrders) { order in
            cal.startOfDay(for: order.deliveryDate)
        }
        return grouped.map { (key: $0.key, orders: $0.value.sorted { $0.deliveryDate < $1.deliveryDate }) }
            .sorted { $0.key < $1.key }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                topControlsBar

                if showDatePicker {
                    dateRangePickerView
                }

                contentView
            }
            .background(DSColor.background)
            .navigationTitle("Pedidos")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        NavigationLink {
                            DashboardView(viewModel: DashboardViewModel())
                        } label: {
                            Label("Painel", systemImage: "chart.bar.xaxis")
                        }

                        NavigationLink {
                            ProductsView()
                        } label: {
                            Label("Produtos", systemImage: "shippingbox.fill")
                        }

                        NavigationLink {
                            ClientsView()
                        } label: {
                            Label("Clientes", systemImage: "person.2.fill")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .foregroundColor(DSColor.brand)
                    }
                }
            }
            .sheet(isPresented: $showingNewOrderSheet) {
                NewOrderView(viewModel: viewModel, state: newOrderState)
            }
            .task { await viewModel.loadOrders() }
            .alert("Erro", isPresented: Binding<Bool>(
                get: { viewModel.errorMessage != nil },
                set: { if !$0 { viewModel.errorMessage = nil } }
            )) {
                Button("OK", role: .cancel) { }
            } message: {
                if let message = viewModel.errorMessage { Text(message) }
            }
        }
    }

    // MARK: - Content

    @ViewBuilder
    private var contentView: some View {
        if viewModel.isLoading && viewModel.orders.isEmpty {
            Spacer()
            ProgressView("Buscando pedidos...")
            Spacer()
        } else if filteredOrders.isEmpty {
            emptyState
        } else {
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(groupedOrders, id: \.key) { group in
                        daySection(date: group.key, orders: group.orders)
                    }
                }
                .padding(.bottom, 80)
            }
            .refreshable { await viewModel.loadOrders() }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "tray")
                .font(.system(size: 48))
                .foregroundColor(DSColor.foregroundSoft)
            Text("Nenhum pedido encontrado")
                .font(.headline)
                .foregroundColor(DSColor.foreground)
            if selectedStatus != nil || !searchText.isEmpty {
                Button("Limpar filtros") {
                    selectedStatus = nil
                    searchText = ""
                }
                .font(.subheadline)
                .foregroundColor(DSColor.brand)
            }
            Spacer()
        }
    }

    // MARK: - Day Section

    private func daySection(date: Date, orders: [Order]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            // Day header
            HStack(alignment: .firstTextBaseline) {
                Text(Formatters.relativeDay(date))
                    .font(DSFont.sectionLabel)
                    .foregroundColor(DSColor.foregroundSoft)
                    .textCase(.uppercase)
                Text(Formatters.shortDate(date))
                    .font(.caption)
                    .foregroundColor(DSColor.foregroundSoft)
                Spacer()
                Text("\(orders.count)")
                    .font(DSFont.monoCaption)
                    .foregroundColor(DSColor.foregroundSoft)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(DSColor.background2)
                    .cornerRadius(4)
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 4)

            // Order cards
            VStack(spacing: 0) {
                ForEach(Array(orders.enumerated()), id: \.element.id) { index, order in
                    NavigationLink(destination: OrderDetailView(order: order, viewModel: viewModel)) {
                        OrderCardV2(order: order)
                    }
                    .buttonStyle(.plain)

                    if index < orders.count - 1 {
                        Divider().padding(.leading, 16)
                    }
                }
            }
            .background(Color.white)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.black.opacity(0.06), lineWidth: 1)
            )
            .padding(.horizontal, 16)
        }
    }
}

// MARK: - Top Controls

private extension OrdersView {
    var topControlsBar: some View {
        HStack(spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .font(.subheadline)
                    .foregroundColor(DSColor.foregroundSoft)
                TextField("Buscar cliente ou pedido...", text: $searchText)
                    .textFieldStyle(.plain)
                    .font(.subheadline)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
            }
            .padding(10)
            .background(DSColor.background2)
            .cornerRadius(10)

            Menu {
                Picker("Status", selection: $selectedStatus) {
                    Text("Todos").tag(OrderStatus?.none)
                    ForEach(OrderStatus.allCases, id: \.self) { status in
                        Label(status.localizedName, systemImage: "circle.fill")
                            .tag(OrderStatus?.some(status))
                    }
                }
            } label: {
                Image(systemName: selectedStatus != nil ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle")
                    .font(.title3)
                    .foregroundColor(selectedStatus == nil ? DSColor.foregroundSoft : DSColor.brand)
            }

            Button {
                withAnimation(.easeInOut(duration: 0.2)) { showDatePicker.toggle() }
            } label: {
                Image(systemName: showDatePicker ? "calendar.circle.fill" : "calendar")
                    .font(.title3)
                    .foregroundColor(showDatePicker ? DSColor.brand : DSColor.foregroundSoft)
            }

            Button { showingNewOrderSheet = true } label: {
                Image(systemName: "plus.circle.fill")
                    .font(.title3)
                    .foregroundColor(DSColor.brand)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color.white)
    }

    var dateRangePickerView: some View {
        VStack(spacing: 12) {
            DatePicker("De:", selection: $startDate, displayedComponents: .date)
                .font(.subheadline)
            DatePicker("Até:", selection: $endDate, displayedComponents: .date)
                .font(.subheadline)
        }
        .padding()
        .background(Color.white)
        .shadow(color: .black.opacity(0.04), radius: 4, x: 0, y: 2)
    }
}

// MARK: - V2 Order Card

struct OrderCardV2: View {
    let order: Order

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Row 1: Client name + delivery time
            HStack(alignment: .firstTextBaseline) {
                Text(order.clientName)
                    .font(DSFont.cardTitle)
                    .foregroundColor(DSColor.foreground)
                    .lineLimit(1)
                Spacer()
                Text(Formatters.shortTime(order.deliveryDate))
                    .font(DSFont.monoCaption)
                    .foregroundColor(DSColor.foregroundSoft)
            }

            // Row 2: Status chip + delivery mode + item count + total
            HStack(spacing: 8) {
                OrderStatusChip(status: order.status)

                if order.isPaid {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.caption2)
                        .foregroundColor(DSColor.ok)
                }

                if let addr = order.deliveryAddress, addr != "Retirada", addr != "pickup", !addr.isEmpty {
                    Label("Entrega", systemImage: "bicycle")
                        .font(.caption2)
                        .foregroundColor(DSColor.foregroundSoft)
                } else {
                    Label("Retirada", systemImage: "bag")
                        .font(.caption2)
                        .foregroundColor(DSColor.foregroundSoft)
                }

                Spacer()

                Text("\(order.items.count) item\(order.items.count == 1 ? "" : "s")")
                    .font(.caption2)
                    .foregroundColor(DSColor.foregroundSoft)

                Text(Formatters.brl(order.totalPaid))
                    .font(DSFont.secondaryAmount)
                    .foregroundColor(DSColor.foreground)
            }

            // Row 3: Order ID
            Text("#\(order.shortId)")
                .font(DSFont.monoCaption)
                .foregroundColor(DSColor.foregroundSoft)
        }
        .padding(14)
    }
}

// MARK: - Status Chip

struct OrderStatusChip: View {
    let status: OrderStatus

    private var chipColor: Color {
        switch status {
        case .received: return .blue
        case .pending: return Color(red: 184/255, green: 121/255, blue: 31/255)
        case .preparing: return .orange
        case .waitingPickupOrDelivery: return .purple
        case .completed: return DSColor.ok
        case .canceled: return DSColor.destructive
        }
    }

    var body: some View {
        Text(status.localizedName)
            .font(.caption2)
            .fontWeight(.semibold)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(chipColor.opacity(0.12))
            .foregroundColor(chipColor)
            .cornerRadius(6)
    }
}
