//
//  OrdersView.swift
//  DeuxOrders
//
//  Created by Theo on 07/03/26.
//

import SwiftUI

struct OrdersView: View {
    @ObservedObject var viewModel: OrdersViewModel
    
    @State private var searchText = ""
    @State private var selectedStatus: OrderStatus? = nil
    
    @State private var startDate = Date()
    @State private var endDate = Calendar.current.date(byAdding: .day, value: 30, to: Date()) ?? Date()
    @State private var showDatePicker = false
    @State private var showingNewOrderSheet = false
    
    private let brandColor = Color(red: 88/255, green: 22/255, blue: 41/255)

    var filteredOrders: [Order] {
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

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                topControlsBar
                
                if showDatePicker {
                    dateRangePickerView
                }
                
                contentView
            }
            .navigationTitle("Pedidos")
            .sheet(isPresented: $showingNewOrderSheet) {
                NewOrderView(viewModel: viewModel)
            }
            .task {
                await viewModel.loadOrders()
            }
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
    
    @ViewBuilder
    private var contentView: some View {
        if viewModel.isLoading && viewModel.orders.isEmpty {
            Spacer()
            ProgressView("Buscando ordens...")
            Spacer()
        } else if filteredOrders.isEmpty {
            ContentUnavailableView("Nenhum pedido", systemImage: "tray.fill")
        } else {
            List {
                ForEach(filteredOrders) { order in
                    ZStack {
                        OrderCard(order: order)
                        NavigationLink(destination: EditOrderView(viewModel: viewModel, order: order)) {
                            EmptyView()
                        }
                        .opacity(0)
                    }
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                    .listRowBackground(Color.clear)
                    .swipeActions(edge: .leading, allowsFullSwipe: true) {
                        Button {
                            Task { await viewModel.updateOrderStatus(order: order, action: .complete) }
                        } label: {
                            Label("Concluir", systemImage: "checkmark.circle.fill")
                        }
                        .tint(.green)
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button {
                            Task { await viewModel.updateOrderStatus(order: order, action: .cancel) }
                        } label: {
                            Label("Cancelar", systemImage: "xmark.circle.fill")
                        }
                        .tint(.red)
                    }
                }
            }
            .listStyle(.plain)
            .background(Color(uiColor: .systemGroupedBackground))
            .scrollContentBackground(.hidden)
            .refreshable { await viewModel.loadOrders() }
        }
    }
}

private extension OrdersView {
    var topControlsBar: some View {
        HStack(spacing: 12) {
            HStack {
                Image(systemName: "magnifyingglass").foregroundColor(.secondary)
                TextField("Buscar...", text: $searchText)
                    .textFieldStyle(.plain)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
            }
            .padding(8)
            .background(Color(uiColor: .secondarySystemBackground))
            .cornerRadius(8)
            
            Menu {
                Picker("Status", selection: $selectedStatus) {
                    Text("Todos").tag(OrderStatus?.none)
                    ForEach(OrderStatus.allCases, id: \.self) { status in
                        Text(status.localizedName).tag(OrderStatus?.some(status))
                    }
                }
            } label: {
                Image(systemName: "line.3.horizontal.decrease.circle")
                    .font(.title2)
                    .foregroundColor(selectedStatus == nil ? brandColor : .blue)
            }
            
            Button {
                withAnimation(.easeInOut) { showDatePicker.toggle() }
            } label: {
                Image(systemName: "calendar")
                    .font(.title2)
                    .foregroundColor(showDatePicker ? .blue : brandColor)
            }
            
            Button {
                showingNewOrderSheet.toggle()
            } label: {
                Image(systemName: "plus.circle.fill")
                    .font(.title2)
                    .foregroundColor(brandColor)
            }
        }
        .padding()
        .background(Color(uiColor: .systemBackground))
    }
    
    var dateRangePickerView: some View {
        VStack(spacing: 12) {
            DatePicker("Data Inicial:", selection: $startDate, displayedComponents: .date)
            DatePicker("Data Final:", selection: $endDate, displayedComponents: .date)
        }
        .padding()
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .shadow(color: .black.opacity(0.05), radius: 3, x: 0, y: 3)
    }
}

struct OrderCard: View {
    let order: Order
    
    private var formattedTotal: String {
        let total = Double(order.totalPaid) / 100.0
        return total.formatted(.currency(code: "BRL").locale(Locale(identifier: "pt_BR")))
    }
    
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Pedido #\(order.id.prefix(6))")
                    .font(.subheadline)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                
                Spacer()
                
                Text(order.deliveryDate.formatted(date: .numeric, time: .omitted))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            HStack {
                Text(order.status.localizedName)
                    .font(.caption2)
                    .fontWeight(.bold)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(order.status.color.opacity(0.2))
                    .foregroundColor(order.status.color)
                    .cornerRadius(6)
                
                Spacer()
                
                Text(formattedTotal)
                    .font(.headline)
                    .foregroundColor(.primary)
            }
        }
        .padding()
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
    }
}
