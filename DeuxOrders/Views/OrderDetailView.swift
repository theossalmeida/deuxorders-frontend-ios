//
//  OrderDetailView.swift
//  DeuxOrders
//

import SwiftUI

struct OrderDetailView: View {
    let order: Order
    @ObservedObject var viewModel: OrdersViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var showUnpayAlert = false
    @State private var unpayReason = ""
    @State private var showCancelAlert = false
    private var isAdmin: Bool { AppSession.isAdministrator }


    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Total + Status
                totalCard

                // Status Pipeline
                statusPipeline

                // Items
                itemsSection

                // Reference Images
                if let refs = order.references, !refs.isEmpty {
                    referencesSection(refs)
                }

                // Delivery Card
                deliveryCard

                // Payment Card
                paymentCard

                // Client Card
                clientCard

                // Actions
                actionsSection
            }
            .padding()
        }
        .navigationTitle(order.clientName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                NavigationLink(destination: EditOrderView(viewModel: viewModel, order: order)) {
                    Text("Editar")
                        .foregroundColor(DSColor.brand)
                }
            }
        }
        .alert("Motivo do estorno", isPresented: $showUnpayAlert) {
            TextField("Informe o motivo", text: $unpayReason)
            Button("Cancelar", role: .cancel) { }
            Button("Reverter", role: .destructive) {
                Task {
                    await viewModel.reversePayment(order: order, reason: unpayReason.isEmpty ? "Estorno pelo app" : unpayReason)
                }
            }
        } message: {
            Text("Informe o motivo para reverter o pagamento.")
        }
        .alert("Cancelar pedido?", isPresented: $showCancelAlert) {
            Button("Não", role: .cancel) { }
            Button("Sim, cancelar", role: .destructive) {
                Task { await viewModel.updateOrderStatus(order: order, action: .cancel) }
            }
        } message: {
            Text("Esta ação não pode ser desfeita.")
        }
    }

    // MARK: - Total Card

    private var totalCard: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("TOTAL DO PEDIDO")
                    .font(.system(size: 10, weight: .semibold))
                    .tracking(1)
                    .foregroundColor(.secondary)
                Text(formatCurrency(order.totalValue))
                    .font(.system(size: 28, weight: .semibold, design: .monospaced))
            }

            Spacer()

            Text(order.status.localizedName)
                .font(.caption)
                .fontWeight(.semibold)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(order.status.color.opacity(0.15))
                .foregroundColor(order.status.color)
                .cornerRadius(8)
        }
        .padding()
        .background(Color(uiColor: .secondarySystemBackground))
        .cornerRadius(16)
    }

    // MARK: - Status Pipeline

    private var statusPipeline: some View {
        let stages: [OrderStatus] = [.received, .preparing, .waitingPickupOrDelivery, .completed]
        let currentIndex = stages.firstIndex(of: order.status)
        let isCanceled = order.status == .canceled

        return VStack(alignment: .leading, spacing: 8) {
            DashboardSectionHeader(title: "STATUS")

            HStack(spacing: 0) {
                ForEach(Array(stages.enumerated()), id: \.element) { index, stage in
                    let isPast = currentIndex != nil && index <= currentIndex!
                    let isCurrent = stage == order.status

                    VStack(spacing: 4) {
                        ZStack {
                            Circle()
                                .fill(isCanceled ? Color.red.opacity(0.2) : (isPast ? stage.color : Color.gray.opacity(0.2)))
                                .frame(width: 28, height: 28)

                            if isCurrent && !isCanceled {
                                Circle()
                                    .fill(stage.color)
                                    .frame(width: 12, height: 12)
                            } else if isPast && !isCanceled {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundColor(.white)
                            }
                        }

                        Text(stage.localizedName)
                            .font(.system(size: 8))
                            .foregroundColor(isPast && !isCanceled ? .primary : .secondary)
                            .lineLimit(2)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)

                    if index < stages.count - 1 {
                        Rectangle()
                            .fill(isPast && !isCanceled && currentIndex != nil && index < currentIndex! ? stages[index].color : Color.gray.opacity(0.2))
                            .frame(height: 2)
                            .frame(maxWidth: .infinity)
                            .offset(y: -10)
                    }
                }
            }

            if isCanceled {
                HStack(spacing: 6) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.red)
                    Text("Pedido cancelado")
                        .font(.caption)
                        .foregroundColor(.red)
                }
                .padding(.top, 4)
            }
        }
        .padding()
        .background(Color(uiColor: .secondarySystemBackground))
        .cornerRadius(12)
    }

    // MARK: - Items

    private var itemsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            DashboardSectionHeader(title: "ITENS")

            VStack(spacing: 0) {
                ForEach(Array(order.items.enumerated()), id: \.offset) { index, item in
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                HStack(spacing: 6) {
                                    Text(item.productName)
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                    if item.itemCanceled {
                                        Text("CANCELADO")
                                            .font(.system(size: 8, weight: .bold))
                                            .foregroundColor(.red)
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 2)
                                            .background(Color.red.opacity(0.1))
                                            .cornerRadius(4)
                                    }
                                }
                                if let size = item.productSize, !size.isEmpty {
                                    Text(size)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }

                            Spacer()

                            VStack(alignment: .trailing, spacing: 2) {
                                Text(formatCurrency(item.totalPaid))
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                Text("\(item.quantity)x \(formatCurrency(item.paidUnitPrice))")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }

                        // Custom fields
                        HStack(spacing: 8) {
                            if let massa = item.massa, !massa.isEmpty {
                                customFieldBadge(label: "Massa", value: massa)
                            }
                            if let sabor = item.sabor, !sabor.isEmpty {
                                customFieldBadge(label: "Sabor", value: sabor)
                            }
                        }

                        if let obs = item.observation, !obs.isEmpty {
                            Text(obs)
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .italic()
                        }
                    }
                    .padding(.vertical, 10)
                    .padding(.horizontal)
                    .opacity(item.itemCanceled ? 0.5 : 1.0)

                    if index < order.items.count - 1 {
                        Divider().padding(.leading)
                    }
                }
            }
            .background(Color(uiColor: .secondarySystemBackground))
            .cornerRadius(12)
        }
    }

    private func customFieldBadge(label: String, value: String) -> some View {
        Text("\(label): \(value)")
            .font(.system(size: 10))
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(DSColor.brand.opacity(0.1))
            .foregroundColor(DSColor.brand)
            .cornerRadius(4)
    }

    // MARK: - References

    private func referencesSection(_ refs: [String]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            DashboardSectionHeader(title: "REFERÊNCIAS")

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(refs, id: \.self) { ref in
                        let url = ref.hasPrefix("http") ? URL(string: ref) : URL(string: "https://deux-erp.deuxcerie.com.br/\(ref)")
                        if let url = url {
                            AsyncImage(url: url) { phase in
                                switch phase {
                                case .success(let image):
                                    image
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                        .frame(width: 100, height: 100)
                                        .clipped()
                                        .cornerRadius(10)
                                default:
                                    RoundedRectangle(cornerRadius: 10)
                                        .fill(Color(uiColor: .tertiarySystemBackground))
                                        .frame(width: 100, height: 100)
                                        .overlay(ProgressView())
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: - Delivery Card

    private var deliveryCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("ENTREGA")
                .font(.system(size: 10, weight: .semibold))
                .tracking(1)
                .foregroundColor(.secondary)

            let addr = order.deliveryAddress ?? ""
            let isDelivery = !addr.isEmpty && addr != "Retirada" && addr != "pickup"

            HStack(spacing: 8) {
                Image(systemName: isDelivery ? "truck.box.fill" : "bag.fill")
                    .foregroundColor(.secondary)
                Text(isDelivery ? "Entrega" : "Retirada")
                    .font(.subheadline)
                    .fontWeight(.medium)
            }

            Text(formatDeliveryDate(order.deliveryDate))
                .font(.subheadline)
                .foregroundColor(.secondary)

            if let address = order.deliveryAddress, !address.isEmpty {
                Text(address)
                    .font(.caption)
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(uiColor: .tertiarySystemBackground))
                    .cornerRadius(8)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(uiColor: .secondarySystemBackground))
        .cornerRadius(12)
    }

    // MARK: - Payment Card

    private var paymentCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("PAGAMENTO")
                .font(.system(size: 10, weight: .semibold))
                .tracking(1)
                .foregroundColor(.secondary)

            HStack {
                Text(order.isPaid ? "Pago" : "Aguardando pagamento")
                    .font(.subheadline)
                    .fontWeight(.medium)

                Spacer()

                if order.isPaid {
                    HStack(spacing: 4) {
                        Circle().fill(Color.green).frame(width: 6, height: 6)
                        Text("Pago")
                            .font(.caption)
                            .fontWeight(.semibold)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Color.green.opacity(0.1))
                    .foregroundColor(.green)
                    .cornerRadius(12)
                } else {
                    Text("Pendente")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Color.orange.opacity(0.1))
                        .foregroundColor(.orange)
                        .cornerRadius(12)
                }
            }

            if let paidAt = order.paidAt {
                HStack(spacing: 4) {
                    Text(formatDeliveryDate(paidAt))
                    if let user = order.paidByUserName {
                        Text("· por \(user)")
                    }
                }
                .font(.system(size: 11, design: .monospaced))
                .foregroundColor(.secondary)
            }

            // Payment actions
            if isAdmin && order.status == .completed && !order.isPaid {
                Button {
                    Task { await viewModel.markAsPaid(order: order) }
                } label: {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                        Text("Marcar como pago")
                    }
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .foregroundColor(.white)
                    .background(Color.green)
                    .cornerRadius(10)
                }
            }

            if isAdmin && order.isPaid {
                Button {
                    unpayReason = ""
                    showUnpayAlert = true
                } label: {
                    HStack {
                        Image(systemName: "arrow.uturn.backward")
                        Text("Reverter pagamento")
                    }
                    .font(.caption)
                    .foregroundColor(.orange)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(uiColor: .secondarySystemBackground))
        .cornerRadius(12)
    }

    // MARK: - Client Card

    private var clientCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("CLIENTE")
                .font(.system(size: 10, weight: .semibold))
                .tracking(1)
                .foregroundColor(.secondary)

            NavigationLink(destination: ClientDetailView(clientId: order.clientId)) {
                HStack(spacing: 12) {
                    Text(String(order.clientName.prefix(1)).uppercased())
                        .font(.subheadline)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .frame(width: 36, height: 36)
                        .background(DSColor.brand)
                        .clipShape(Circle())

                    Text(order.clientName)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(uiColor: .secondarySystemBackground))
        .cornerRadius(12)
    }

    // MARK: - Actions

    private var actionsSection: some View {
        VStack(spacing: 10) {
            if let nextStatus = order.nextStatus {
                Button {
                    if nextStatus == .completed {
                        Task { await viewModel.updateOrderStatus(order: order, action: .complete) }
                    } else {
                        Task {
                            let updateInput = UpdateOrderRequest(
                                deliveryDate: nil,
                                status: nextStatus.intValue,
                                deliveryAddress: nil,
                                items: nil,
                                references: nil
                            )
                            try? await viewModel.orderService.updateOrder(id: order.id, input: updateInput)
                            await viewModel.loadOrders()
                        }
                    }
                } label: {
                    HStack {
                        Image(systemName: "arrow.right.circle.fill")
                        Text("Avançar para \(nextStatus.localizedName)")
                    }
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .foregroundColor(.white)
                    .background(DSColor.brand)
                    .cornerRadius(12)
                }
            }

            if order.status != .completed && order.status != .canceled {
                Button {
                    showCancelAlert = true
                } label: {
                    HStack {
                        Image(systemName: "xmark.circle")
                        Text("Cancelar pedido")
                    }
                    .font(.subheadline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .foregroundColor(.red)
                }
                .background(Color.red.opacity(0.1))
                .cornerRadius(12)
            }
        }
    }

    // MARK: - Helpers

    private func formatCurrency(_ cents: Int) -> String {
        Formatters.currency.string(from: NSNumber(value: Double(cents) / 100.0)) ?? "R$ 0,00"
    }

    private func formatDeliveryDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "pt_BR")
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}
