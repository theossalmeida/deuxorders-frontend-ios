//
//  ClientsViewModel.swift
//  DeuxOrders
//
//  Created by Theo on 11/03/26.
//


import Foundation
import Combine

@MainActor
class ClientsViewModel: ObservableObject {
    @Published var clients: [Client] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let clientService: ClientService

    init(clientService: ClientService? = nil) {
        self.clientService = clientService ?? ClientService()
    }

    func loadClients() async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            self.clients = try await clientService.fetchClients()
            self.errorMessage = nil
        } catch {
            self.errorMessage = "Falha ao carregar a lista de clientes."
        }
    }
    
    func addClient(name: String, mobile: String) async -> Bool {
        let cleanedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanedMobile = mobile.trimmingCharacters(in: .whitespacesAndNewlines)
        let finalMobile = cleanedMobile.isEmpty ? nil : cleanedMobile
        
        let input = ClientInput(name: cleanedName, mobile: finalMobile)
        
        do {
            try await clientService.createClient(input: input)
            // Reloads entire list because we need the backend-generated UUID for the new client.
            // A more performant backend would return the created Client object here.
            await loadClients()
            return true
        } catch {
            self.errorMessage = "Falha ao criar o cliente. Verifique a conexão."
            return false
        }
    }
    
    func deleteClient(id: String) async {
        do {
            try await clientService.deleteClient(id: id)
            clients.removeAll { $0.id == id }
        } catch {
            self.errorMessage = "Este cliente possui pedidos associados e não pode ser excluído. Sugerimos que seja desativado."
        }
    }
    
    func deactivateClient(id: String) async {
        guard let index = clients.firstIndex(where: { $0.id == id }) else { return }
        
        let originalState = clients[index].isActive
        clients[index].isActive = false
        
        do {
            try await clientService.deactivateClient(id: id)
        } catch {
            clients[index].isActive = originalState
            self.errorMessage = "Falha ao comunicar desativação ao servidor."
        }
    }
}
