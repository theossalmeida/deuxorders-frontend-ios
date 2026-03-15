//
//  OrdersViewModel.swift
//  DeuxOrders
//
//  Created by Theo on 07/03/26.
//

import Foundation
import Combine

enum OrderAction {
    case complete
    case cancel
}

@MainActor
class OrdersViewModel: ObservableObject {
    @Published var orders: [Order] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    let orderService: OrderService

    init(orderService: OrderService) {
        self.orderService = orderService
    }

    func loadOrders() async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            self.orders = try await orderService.fetchOrders()
            self.errorMessage = nil
            await NotificationService.shared.scheduleNotifications(orders: self.orders)
        } catch let DecodingError.dataCorrupted(context) {
            print("🚨 ERRO DE PARSING: Dados corrompidos - \(context.debugDescription)")
            self.errorMessage = "Erro interno: Dados mal formatados."
        } catch let DecodingError.keyNotFound(key, context) {
            print("🚨 ERRO DE PARSING: Chave '\(key.stringValue)' ausente no JSON. Path: \(context.codingPath)")
            self.errorMessage = "Erro interno: Resposta da API incompatível."
        } catch let DecodingError.typeMismatch(type, context) {
            print("🚨 ERRO DE PARSING: Tipo incorreto. Esperava \(type). Path: \(context.codingPath)")
            self.errorMessage = "Erro interno: Tipo de dado inválido."
        } catch let DecodingError.valueNotFound(type, context) {
            print("🚨 ERRO DE PARSING: Valor nulo encontrado onde era esperado \(type). Path: \(context.codingPath)")
            self.errorMessage = "Erro interno: Valor nulo inesperado."
        } catch let error as NetworkError {
            print("🚨 ERRO DE REDE: \(error)")
            self.errorMessage = "Falha de conexão com o servidor."
        } catch is CancellationError {
            return
        } catch let error as URLError {
            print("🚨 ERRO DE URL: \(error)")
            self.errorMessage = "Não foi possível conectar ao servidor. Verifique sua conexão."
        } catch {
            print("🚨 ERRO DESCONHECIDO (\(type(of: error))): \(error)")
            self.errorMessage = "Ocorreu um erro inesperado."
        }
    }
    
    func deleteOrder(id: String) async throws {
        do {
            try await orderService.deleteOrder(id: id)
            orders.removeAll { $0.id == id }
        } catch {
            self.errorMessage = "Falha ao deletar pedido."
            throw error
        }
    }
    
    func updateOrderStatus(order: Order, action: OrderAction) async {
        guard let index = orders.firstIndex(where: { $0.id == order.id }) else { return }
        
        let originalStatus = orders[index].status
        orders[index].status = action == .complete ? .completed : .canceled
        
        do {
            switch action {
            case .complete:
                try await orderService.completeOrder(id: order.id)
            case .cancel:
                try await orderService.cancelOrder(id: order.id)
            }
            await loadOrders()
        } catch {
            orders[index].status = originalStatus
            self.errorMessage = "Ação falhou. As alterações foram revertidas."
        }
    }
}
