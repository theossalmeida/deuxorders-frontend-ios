//
//  DashboardView.swift
//  DeuxOrders
//
//  Created by Theo on 04/03/26.
//

import SwiftUI

struct DashboardView: View {
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Resumo Financeiro
                    VStack(alignment: .leading, spacing: 10) {
                        Text("RESUMO DE HOJE")
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundColor(.secondary)
                        
                        HStack(spacing: 15) {
                            SummaryCard(title: "Vendas", value: "R$ 2.450", icon: "dollarsign.circle.fill", color: .green)
                            SummaryCard(title: "Pedidos", value: "18", icon: "cart.badge.plus", color: .blue)
                        }
                    }
                    .padding(.horizontal)

                    // Seção de Atividade Recente
                    VStack(alignment: .leading) {
                        Text("ATIVIDADE RECENTE")
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundColor(.secondary)
                            .padding(.horizontal)

                        VStack(spacing: 12) {
                            ForEach(0..<3) { _ in
                                ActivityRow()
                            }
                        }
                        .padding()
                        .background(Color(uiColor: .secondarySystemBackground))
                        .cornerRadius(15)
                        .padding(.horizontal)
                    }
                }
                .padding(.vertical)
            }
            .navigationTitle("Dashboard")
        }
    }
}

// Componente de Card para o Dashboard
struct SummaryCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: icon)
                .foregroundColor(color)
                .font(.title3)
            
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(uiColor: .tertiarySystemBackground))
        .cornerRadius(15)
        .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
    }
}

struct ActivityRow: View {
    var body: some View {
        HStack {
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.green)
            VStack(alignment: .leading) {
                Text("Pedido #1240 aprovado")
                    .font(.subheadline)
                    .fontWeight(.medium)
                Text("Há 10 minutos")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            Spacer()
            Text("R$ 150,00").font(.footnote).bold()
        }
    }
}
