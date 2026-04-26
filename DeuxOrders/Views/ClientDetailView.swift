//
//  ClientDetailView.swift
//  DeuxOrders
//

import SwiftUI

struct ClientDetailView: View {
    let clientId: String

    @State private var detail: ClientDetail?
    @State private var isLoading = true
    @State private var errorMessage: String?

    private let service = ClientService()

    var body: some View {
        ScrollView {
            if isLoading {
                ProgressView("Carregando...")
                    .frame(maxWidth: .infinity)
                    .padding(.top, 60)
            } else if let error = errorMessage {
                VStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.largeTitle)
                        .foregroundColor(.secondary)
                    Text(error)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 60)
            } else if let client = detail {
                VStack(spacing: 16) {
                    kpiBand(client.stats)
                    contactCard(client)
                    ordersHistorySection(client.orders.items)
                }
                .padding()
            }
        }
        .navigationTitle(detail?.name ?? "Cliente")
        .navigationBarTitleDisplayMode(.inline)
        .task { await loadDetail() }
        .refreshable { await loadDetail() }
    }

    // MARK: - KPI Band

    private func kpiBand(_ stats: ClientStats) -> some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
            kpiCard(title: "Pedidos", value: "\(stats.totalOrders)", icon: "cart.fill", color: .blue)
            kpiCard(title: "Total gasto", value: formatCurrency(stats.totalSpent), icon: "banknote.fill", color: .green)
            kpiCard(title: "Ticket médio", value: formatCurrency(stats.totalOrders > 0 ? stats.totalSpent / stats.totalOrders : 0), icon: "chart.line.uptrend.xyaxis", color: DSColor.brand)
            kpiCard(title: "Último pedido", value: stats.lastOrderDate.map(formatOrderDate) ?? "—", icon: "calendar", color: .orange)
        }
    }

    private func kpiCard(title: String, value: String, icon: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Image(systemName: icon)
                .foregroundColor(color)
                .font(.caption)
            Text(value)
                .font(.headline)
                .fontWeight(.bold)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color(uiColor: .secondarySystemBackground))
        .cornerRadius(10)
    }

    // MARK: - Contact Card

    private func contactCard(_ client: ClientDetail) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                // Avatar
                Text(String(client.name.prefix(1)).uppercased())
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .frame(width: 40, height: 40)
                    .background(DSColor.brand)
                    .clipShape(Circle())

                VStack(alignment: .leading, spacing: 2) {
                    Text(client.name)
                        .font(.headline)
                    HStack(spacing: 6) {
                        Circle()
                            .fill(client.status ? Color.green : Color.red)
                            .frame(width: 6, height: 6)
                        Text(client.status ? "Ativo" : "Inativo")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                Spacer()
            }
            .padding()

            if let mobile = client.mobile, !mobile.isEmpty {
                Divider().padding(.leading, 64)

                Button {
                    if let url = URL(string: "tel:\(mobile)") {
                        UIApplication.shared.open(url)
                    }
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "phone.fill")
                            .foregroundColor(DSColor.brand)
                            .frame(width: 40)
                        Text(mobile)
                            .font(.subheadline)
                            .foregroundColor(.primary)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                }
            }
        }
        .background(Color(uiColor: .secondarySystemBackground))
        .cornerRadius(12)
    }

    // MARK: - Orders History

    private func ordersHistorySection(_ orders: [ClientOrder]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            DashboardSectionHeader(title: "HISTÓRICO DE PEDIDOS")

            if orders.isEmpty {
                Text("Nenhum pedido encontrado")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 24)
                    .background(Color(uiColor: .secondarySystemBackground))
                    .cornerRadius(12)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(orders.enumerated()), id: \.element.id) { index, order in
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(formatOrderDate(order.deliveryDate))
                                    .font(.subheadline)
                                Text(order.status.localizedName)
                                    .font(.caption)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 2)
                                    .background(order.status.color.opacity(0.15))
                                    .foregroundColor(order.status.color)
                                    .cornerRadius(4)
                            }

                            Spacer()

                            Text(formatCurrency(order.totalPaid))
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundColor(DSColor.brand)
                        }
                        .padding(.vertical, 10)
                        .padding(.horizontal)

                        if index < orders.count - 1 {
                            Divider().padding(.leading)
                        }
                    }
                }
                .background(Color(uiColor: .secondarySystemBackground))
                .cornerRadius(12)
            }
        }
    }

    // MARK: - Helpers

    private func loadDetail() async {
        isLoading = true
        defer { isLoading = false }
        do {
            detail = try await service.fetchClientDetail(id: clientId)
            errorMessage = nil
        } catch {
            errorMessage = "Falha ao carregar detalhes do cliente."
        }
    }

    private func formatCurrency(_ cents: Int) -> String {
        Formatters.currency.string(from: NSNumber(value: Double(cents) / 100.0)) ?? "R$ 0,00"
    }

    private func formatOrderDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "pt_BR")
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }
}
