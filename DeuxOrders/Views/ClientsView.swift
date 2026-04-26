//
//  ClientsView.swift
//  DeuxOrders
//
//  Created by Theo on 11/03/26.
//

import SwiftUI

struct ClientsView: View {
    @StateObject private var viewModel = ClientsViewModel()

    @State private var searchText = ""
    @State private var showActiveOnly = true
    @State private var showAddClientSheet = false
    @State private var selectedClient: Client?


    var filteredClients: [Client] {
        viewModel.clients.filter { client in
            let searchMatch = searchText.isEmpty || client.name.localizedCaseInsensitiveContains(searchText)
            let statusMatch = client.status == showActiveOnly
            return searchMatch && statusMatch
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                topControlsBar
                contentView
            }
            .navigationTitle("Clientes")
            .task {
                await viewModel.loadClients()
            }
            .alert("Atenção", isPresented: Binding<Bool>(
                get: { viewModel.errorMessage != nil },
                set: { if !$0 { viewModel.errorMessage = nil } }
            )) {
                Button("OK", role: .cancel) { }
            } message: {
                if let message = viewModel.errorMessage { Text(message) }
            }
            .sheet(isPresented: $showAddClientSheet) {
                AddClientView(viewModel: viewModel)
            }
            .sheet(item: $selectedClient) { client in
                EditClientView(client: client, viewModel: viewModel)
            }
        }
    }

    @ViewBuilder
    private var contentView: some View {
        if viewModel.isLoading && viewModel.clients.isEmpty {
            Spacer()
            ProgressView("Buscando clientes...")
            Spacer()
        } else if filteredClients.isEmpty {
            ContentUnavailableView("Nenhum cliente encontrado", systemImage: "person.slash.fill")
        } else {
            List {
                ForEach(filteredClients) { client in
                    ZStack {
                        ClientCard(client: client)
                        NavigationLink(destination: ClientDetailView(clientId: client.id)) {
                            EmptyView()
                        }
                        .opacity(0)
                    }
                        .listRowSeparator(.hidden)
                        .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                        .listRowBackground(Color.clear)
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button(role: .destructive) {
                                Task { await viewModel.deleteClient(id: client.id) }
                            } label: {
                                Label("Excluir", systemImage: "trash.fill")
                            }
                        }
                        .swipeActions(edge: .leading, allowsFullSwipe: true) {
                            if client.status {
                                Button {
                                    Task { await viewModel.deactivateClient(id: client.id) }
                                } label: {
                                    Label("Desativar", systemImage: "person.crop.circle.badge.xmark")
                                }
                                .tint(.orange)
                            } else {
                                Button {
                                    Task { await viewModel.activateClient(id: client.id) }
                                } label: {
                                    Label("Ativar", systemImage: "person.crop.circle.badge.checkmark")
                                }
                                .tint(.green)
                            }
                        }
                }
            }
            .listStyle(.plain)
            .background(Color(uiColor: .systemGroupedBackground))
            .scrollContentBackground(.hidden)
            .refreshable { await viewModel.loadClients() }
        }
    }
}

private extension ClientsView {
    var topControlsBar: some View {
        HStack(spacing: 12) {
            HStack {
                Image(systemName: "magnifyingglass").foregroundColor(.secondary)
                TextField("Buscar cliente...", text: $searchText)
                    .textFieldStyle(.plain)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
            }
            .padding(8)
            .background(Color(uiColor: .secondarySystemBackground))
            .cornerRadius(8)

            Menu {
                Picker("Status", selection: $showActiveOnly) {
                    Text("Ativos").tag(true)
                    Text("Inativos").tag(false)
                }
            } label: {
                Image(systemName: "line.3.horizontal.decrease.circle")
                    .font(.title2)
                    .foregroundColor(DSColor.brand)
            }

            Button {
                showAddClientSheet = true
            } label: {
                Image(systemName: "plus.circle.fill")
                    .font(.title2)
                    .foregroundColor(DSColor.brand)
            }
        }
        .padding()
        .background(Color(uiColor: .systemBackground))
    }
}

// MARK: - Add Client Sheet

struct AddClientView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: ClientsViewModel

    @State private var name = ""
    @State private var mobile = ""
    @State private var isSubmitting = false

    var isFormValid: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Dados do Cliente")) {
                    TextField("Nome *", text: $name)
                        .textContentType(.name)
                        .autocorrectionDisabled()

                    TextField("Celular (Opcional)", text: $mobile)
                        .keyboardType(.numberPad)
                        .textContentType(.telephoneNumber)
                }
            }
            .navigationTitle("Novo Cliente")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Salvar") { submit() }
                        .disabled(!isFormValid || isSubmitting)
                }
            }
            .overlay {
                if isSubmitting {
                    ProgressView()
                        .padding()
                        .background(.ultraThinMaterial)
                        .cornerRadius(8)
                }
            }
        }
        .interactiveDismissDisabled(isSubmitting)
    }

    private func submit() {
        isSubmitting = true
        Task {
            let success = await viewModel.addClient(name: name, mobile: mobile)
            isSubmitting = false
            if success { dismiss() }
        }
    }
}

// MARK: - Edit Client Sheet

struct EditClientView: View {
    @Environment(\.dismiss) private var dismiss
    let client: Client
    @ObservedObject var viewModel: ClientsViewModel

    @State private var name: String
    @State private var mobile: String
    @State private var isSubmitting = false

    init(client: Client, viewModel: ClientsViewModel) {
        self.client = client
        self.viewModel = viewModel
        _name = State(initialValue: client.name)
        _mobile = State(initialValue: client.mobile ?? "")
    }

    var isFormValid: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Dados do Cliente")) {
                    TextField("Nome *", text: $name)
                        .textContentType(.name)
                        .autocorrectionDisabled()

                    TextField("Celular (Opcional)", text: $mobile)
                        .keyboardType(.numberPad)
                        .textContentType(.telephoneNumber)
                }
            }
            .navigationTitle("Editar Cliente")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Salvar") { submit() }
                        .disabled(!isFormValid || isSubmitting)
                }
            }
            .overlay {
                if isSubmitting {
                    ProgressView()
                        .padding()
                        .background(.ultraThinMaterial)
                        .cornerRadius(8)
                }
            }
        }
        .interactiveDismissDisabled(isSubmitting)
    }

    private func submit() {
        isSubmitting = true
        Task {
            let success = await viewModel.updateClient(id: client.id, name: name, mobile: mobile)
            isSubmitting = false
            if success { dismiss() }
        }
    }
}

// MARK: - Client Card

struct ClientCard: View {
    let client: Client

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(client.name)
                    .font(.headline)
                    .foregroundColor(.primary)

                Spacer()

                if !client.status {
                    Text("Inativo")
                        .font(.caption2)
                        .fontWeight(.bold)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.gray.opacity(0.2))
                        .foregroundColor(.gray)
                        .cornerRadius(6)
                }
            }

            if let mobile = client.mobile, !mobile.isEmpty {
                Text(mobile)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
    }
}
